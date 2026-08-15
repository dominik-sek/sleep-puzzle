# A single editable field of the public site, addressed by a "page.section.field"
# key declared in config/content_blocks.yml (see ContentBlock::Registry).
#
# One row per key holds both languages, rather than one row per key+locale. That
# keeps the two versions on a single edit screen — which is how you actually
# translate, against the source — and makes it impossible for a key to exist in
# one language but not the other.
#
# Plain fields (titles) live in value_pl/value_en; rich fields use Action Text,
# so a heading does not have to be typed into a formatting editor and does not
# come back wrapped in <div class="trix-content">.
class ContentBlock < ApplicationRecord
  LOCALES = %i[pl en].freeze

  has_rich_text :body_pl
  has_rich_text :body_en

  validates :key, presence: true, uniqueness: true
  validate :key_must_be_declared

  scope :declared, -> { where(key: Registry.keys) }
  scope :with_bodies, -> { with_rich_text_body_pl.with_rich_text_body_en }

  class << self
    # idempotent: safe to re-run on every deploy
    def sync!
      Registry.keys.each { |key| find_or_create_by!(key: key) }
    end

    # rows whose key is no longer declared; kept rather than deleted so removing
    # a field from the YAML by mistake does not destroy the copy with it
    def undeclared
      where.not(key: Registry.keys)
    end
  end

  def field
    Registry.field(key)
  end

  def label
    field&.label || key
  end

  def rich?
    field&.rich? || false
  end

  # The value for a locale, falling back to the default locale when the
  # translation is empty: a blank section is worse than an untranslated one, and
  # it mirrors config.i18n.fallbacks, which is already on in production.
  #
  # Returns an ActionText::RichText for rich fields and a String for plain ones.
  # Returns nil when neither language has anything, so callers can decide what
  # an unfilled block should look like rather than rendering empty markup.
  def value_for(locale = I18n.locale)
    requested = raw_value(locale)
    return requested if present_value?(requested)

    fallback = raw_value(I18n.default_locale)
    fallback if present_value?(fallback)
  end

  def translated?(locale)
    present_value?(raw_value(locale))
  end

  private

  def raw_value(locale)
    return unless LOCALES.include?(locale.to_sym)

    rich? ? public_send(:"body_#{locale}") : public_send(:"value_#{locale}")
  end

  def present_value?(value)
    return false if value.nil?

    value.is_a?(ActionText::RichText) ? value.body.present? : value.present?
  end

  def key_must_be_declared
    return if Registry.key?(key)

    errors.add(:key, "is not declared in config/content_blocks.yml")
  end
end
