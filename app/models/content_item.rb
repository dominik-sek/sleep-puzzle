# One entry in a repeating list the owner controls — a process step, a stat.
#
# Unlike ContentBlock, whose keys are fixed by config/content_blocks.yml, items
# are created and deleted from the admin panel: their *shape* is declared (the
# collection's fields), but how many there are is the owner's call.
#
# Values are a jsonb hash of field => locale => string. Items carry short plain
# strings, so there is no Action Text here.
class ContentItem < ApplicationRecord
  LOCALES = ContentBlock::LOCALES

  validates :collection_key, presence: true
  validate :collection_must_be_declared

  scope :for_collection, ->(key) { where(collection_key: key).order(:position, :id) }
  scope :declared, -> { where(collection_key: ContentBlock::Registry.sections.select(&:collection?).map(&:full_key)) }

  # Materialises each collection's declared defaults as real rows, so the panel
  # opens on an editable list rather than an empty one. Skips any collection that
  # already has items — the owner's list is theirs, defaults never overwrite it.
  def self.sync!
    ContentBlock::Registry.sections.select(&:collection?).each do |section|
      collection = section.collection
      next if for_collection(collection.full_key).exists?

      collection.defaults.each_with_index do |values, index|
        item = new(collection_key: collection.full_key, position: index + 1)

        collection.fields.each do |field|
          (values[field.key] || {}).each { |locale, value| item.assign_value(field.key, locale, value) }
        end

        item.save!
      end
    end
  end

  def collection
    ContentBlock::Registry.collection(collection_key)
  end

  # Falls back to the default locale, matching ContentBlock#value_for.
  def value_for(field_key, locale = I18n.locale)
    per_locale = values[field_key.to_s] || {}

    per_locale[locale.to_s].presence || per_locale[I18n.default_locale.to_s].presence
  end

  # field => resolved string, for rendering a whole item at once
  def to_values(locale = I18n.locale)
    collection.fields.to_h { |field| [ field.key, value_for(field.key, locale) ] }
  end

  # Non-mutating so Active Record still sees the change; assigning into the
  # existing hash in place would not mark the attribute dirty.
  def assign_value(field_key, locale, value)
    current = values[field_key.to_s] || {}
    self.values = values.merge(field_key.to_s => current.merge(locale.to_s => value.to_s))
  end

  private

  def collection_must_be_declared
    return if collection

    errors.add(:collection_key, "is not a collection declared in config/content_blocks.yml")
  end
end
