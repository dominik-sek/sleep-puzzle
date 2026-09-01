# One entry in a repeating list the owner controls - a process step, a stat.
#
# Unlike ContentBlock, whose keys are fixed by config/content_blocks.yml, items
# are created and deleted from the admin panel: their *shape* is declared (the
# collection's fields), but how many there are is the owner's call.
#
# Values are a jsonb hash of field => locale => string, handled by Translatable.
# Items carry short plain strings, so there is no Action Text here.
# == Schema Information
#
# Table name: content_items
#
#  id             :bigint           not null, primary key
#  collection_key :string           not null
#  position       :integer          default(0), not null
#  values         :jsonb            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_content_items_on_collection_key_and_position  (collection_key,position)
#
class ContentItem < ApplicationRecord
  include Translatable

  LOCALES = Translatable::LOCALES

  # No field list: a collection's shape comes from the registry at runtime, so
  # there is nothing to generate readers for at boot.
  translates store: :values

  validates :collection_key, presence: true
  validate :collection_must_be_declared

  scope :for_collection, ->(key) { where(collection_key: key).order(:position, :id) }
  scope :declared, -> { where(collection_key: ContentBlock::Registry.sections.select(&:collection?).map(&:full_key)) }

  # Materialises each collection's declared defaults as real rows, so the panel
  # opens on an editable list rather than an empty one. Skips any collection that
  # already has items - the owner's list is theirs, defaults never overwrite it.
  def self.sync!
    ContentBlock::Registry.sections.select(&:collection?).each do |section|
      materialise_defaults!(section.collection)
    end
  end

  # One collection's half of sync!. Anything that appends to a list has to call
  # this first: a collection with no rows renders from its declared defaults, so
  # creating the first row would replace the whole list with that one row rather
  # than adding to it.
  def self.materialise_defaults!(collection)
    return if for_collection(collection.full_key).exists?

    collection.defaults.each_with_index do |values, index|
      item = new(collection_key: collection.full_key, position: index + 1)

      collection.fields.each do |field|
        (values[field.key] || {}).each { |locale, value| item.assign_value(field.key, locale, value) }
      end

      item.save!
    end
  end

  def collection
    ContentBlock::Registry.collection(collection_key)
  end

  # Named for the collection field it reads, rather than Translatable's generic
  # #translated_value, because callers here always mean "this item's field".
  def value_for(field_key, locale = I18n.locale)
    translated_value(field_key, locale)
  end

  # field => resolved string, for rendering a whole item at once
  def to_values(locale = I18n.locale)
    collection.fields.to_h { |field| [ field.key, value_for(field.key, locale) ] }
  end

  def assign_value(field_key, locale, value)
    assign_translation(field_key, locale, value)
  end

  private

  def collection_must_be_declared
    return if collection

    errors.add(:collection_key, "is not a collection declared in config/content_blocks.yml")
  end
end
