# frozen_string_literal: true

# Reads config/content_blocks.yml and exposes it as pages > sections > fields.
#
# The registry is the only place keys are defined. A key is "page.section.field",
# flattened from the nesting rather than written out by hand, so the tree in the
# admin panel and the keys in the database can never disagree.
class ContentBlock
  module Registry
    PATH = Rails.root.join("config/content_blocks.yml")
    TYPES = %w[plain rich image].freeze

    Field = Struct.new(:key, :label, :type, :defaults, :section, keyword_init: true) do
      def full_key = "#{section.full_key}.#{key}"
      def rich? = type == "rich"
      def plain? = type == "plain"

      # An uploaded picture rather than copy: one file per key, not one per
      # language, because a photo of the owner is the same in both.
      def image? = type == "image"

      # Copy the owner types, as opposed to a file they upload. Only these have
      # a Polish/English pair in the panel.
      def translatable? = !image?

      # The copy the page ships with, used when the database has nothing. Falls
      # back to the default locale so only `pl` has to be written out.
      def default_for(locale = I18n.locale)
        defaults[locale.to_s].presence || defaults[I18n.default_locale.to_s].presence
      end
    end

    # A field of a collection item. Items hold short plain strings only, so there
    # is no `rich` here and no Action Text behind them.
    ItemField = Struct.new(:key, :label, :type, keyword_init: true)

    # A repeating list the owner can add to and remove from. At most one per
    # section, keyed by the section itself.
    Collection = Struct.new(:item_label, :fields, :defaults, :section, keyword_init: true) do
      def full_key = section.full_key

      # Seeds the list when the database has none, so a fresh deploy still shows
      # something. Each entry maps field key => value for the locale.
      def default_items(locale = I18n.locale)
        defaults.map do |item|
          fields.to_h do |field|
            per_locale = item[field.key] || {}
            [ field.key, per_locale[locale.to_s].presence || per_locale[I18n.default_locale.to_s] ]
          end
        end
      end
    end

    Section = Struct.new(:key, :label, :fields, :collection, :page, keyword_init: true) do
      def full_key = "#{page.key}.#{key}"
      def collection? = !collection.nil?
    end

    Page = Struct.new(:key, :label, :sections, keyword_init: true)

    class << self
      def pages
        # reloaded every request in development so editing the YAML doesn't need
        # a server restart; built once everywhere else
        return build_pages if Rails.env.development?

        @pages ||= build_pages
      end

      def keys
        fields.map(&:full_key)
      end

      def fields
        pages.flat_map { |page| page.sections.flat_map(&:fields) }
      end

      def sections
        pages.flat_map(&:sections)
      end

      def section(full_key)
        sections.find { |candidate| candidate.full_key == full_key }
      end

      def collection(full_key)
        section(full_key)&.collection
      end

      def field(full_key)
        fields.find { |field| field.full_key == full_key }
      end

      def key?(full_key)
        keys.include?(full_key)
      end

      private

      def build_collection(config, section)
        return if config.nil?

        fields = config.fetch("fields").map do |field_key, field_config|
          type = field_config.fetch("type")
          raise ArgumentError, "Collection items support only plain fields; got #{type.inspect} for #{section.full_key}.#{field_key}" unless type == "plain"

          ItemField.new(key: field_key, label: field_config.fetch("label"), type: type)
        end

        Collection.new(
          item_label: config.fetch("item_label"),
          fields: fields,
          defaults: config.fetch("defaults", []),
          section: section
        )
      end

      def build_pages
        YAML.safe_load_file(PATH).map do |page_key, page_config|
          page = Page.new(key: page_key, label: page_config.fetch("label"), sections: [])

          page.sections = page_config.fetch("sections").map do |section_key, section_config|
            section = Section.new(
              key: section_key,
              label: section_config.fetch("label"),
              page: page,
              fields: []
            )

            section.collection = build_collection(section_config["collection"], section)

            section.fields = section_config.fetch("fields", {}).map do |field_key, field_config|
              type = field_config.fetch("type")
              raise ArgumentError, "Unknown content block type #{type.inspect} for #{page_key}.#{section_key}.#{field_key}" unless TYPES.include?(type)

              Field.new(
                key: field_key,
                label: field_config.fetch("label"),
                type: type,
                defaults: field_config.fetch("default", {}),
                section: section
              )
            end

            section
          end

          page
        end
      end
    end
  end
end
