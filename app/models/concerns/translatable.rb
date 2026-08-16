# Per-locale values kept in a single jsonb column, shaped field => locale => value.
#
# Used by records that carry copy but also have identity — a package a booking
# points at, a product someone bought. ContentBlock cannot serve them: its keys
# are declared in config/content_blocks.yml and nothing can hold a foreign key to
# a row addressed by string key.
#
# One column rather than name_pl/name_en pairs, so adding a translated field is a
# model change and not a migration, and so the shape matches ContentItem — which
# was already storing owner-edited copy this way before this concern existed.
module Translatable
  extend ActiveSupport::Concern

  LOCALES = %i[pl en].freeze

  class_methods do
    # Declares the jsonb column holding translations and the fields to generate
    # readers for. `translates :name` gives you `#name` returning the current
    # locale's value, so call sites read like plain attributes — which is what
    # keeps `booking.package.name` working in the mailers unchanged.
    #
    # `lists:` fields hold an array per locale (a package's bullet points) and
    # always read back as an array, so a view can iterate without a nil guard.
    #
    # ContentItem passes no fields at all: its shape comes from the registry at
    # runtime, so there is nothing to generate at boot.
    def translates(*fields, lists: [], store: :translations)
      self.translations_store = store.to_s
      self.translated_fields = fields.map(&:to_s).freeze
      self.translated_list_fields = lists.map(&:to_s).freeze

      translated_fields.each do |field|
        define_method(field) { translated_value(field) }
      end

      translated_list_fields.each do |field|
        define_method(field) { translated_list(field) }
      end
    end
  end

  included do
    class_attribute :translations_store, instance_writer: false, default: "translations"
    class_attribute :translated_fields, instance_writer: false, default: [].freeze
    class_attribute :translated_list_fields, instance_writer: false, default: [].freeze
  end

  # Falls back to the default locale when the translation is empty, matching
  # ContentBlock#value_for and config.i18n.fallbacks: a blank field reads as a
  # broken page, an untranslated one only as an unfinished translation.
  def translated_value(field, locale = I18n.locale)
    per_locale = translations_hash[field.to_s] || {}

    per_locale[locale.to_s].presence || per_locale[I18n.default_locale.to_s].presence
  end

  def translated_list(field, locale = I18n.locale)
    Array(translated_value(field, locale))
  end

  # The stored value, with no fallback. The admin form edits with this: showing
  # the Polish text in the English box would turn "not translated yet" into
  # "translated, identically" the moment the form was saved.
  def raw_translation(field, locale)
    translations_hash.dig(field.to_s, locale.to_s)
  end

  def translated?(field, locale)
    raw_translation(field, locale).present?
  end

  # Non-mutating so Active Record still sees the change; assigning into the
  # existing hash in place would not mark the attribute dirty.
  def assign_translation(field, locale, value)
    write_translation(field, locale, value.to_s)
  end

  # Blank entries are dropped rather than stored: the admin edits these as a
  # textarea, and a stray newline should not become an empty bullet.
  def assign_translation_list(field, locale, values)
    write_translation(field, locale, Array(values).map { |value| value.to_s.strip }.reject(&:empty?))
  end

  private

  def write_translation(field, locale, value)
    current = translations_hash[field.to_s] || {}
    merged = translations_hash.merge(field.to_s => current.merge(locale.to_s => value))

    public_send(:"#{translations_store}=", merged)
  end

  def translations_hash
    public_send(translations_store) || {}
  end
end
