# frozen_string_literal: true

# Reads config/content_blocks.yml and exposes it as pages > sections > fields.
#
# The registry is the only place keys are defined. A key is "page.section.field",
# flattened from the nesting rather than written out by hand, so the tree in the
# admin panel and the keys in the database can never disagree.
class ContentBlock
  module Registry
    PATH = Rails.root.join("config/content_blocks.yml")
    TYPES = %w[plain rich].freeze

    Field = Struct.new(:key, :label, :type, :section, keyword_init: true) do
      def full_key = "#{section.full_key}.#{key}"
      def rich? = type == "rich"
      def plain? = type == "plain"
    end

    Section = Struct.new(:key, :label, :fields, :page, keyword_init: true) do
      def full_key = "#{page.key}.#{key}"
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

      def field(full_key)
        fields.find { |field| field.full_key == full_key }
      end

      def key?(full_key)
        keys.include?(full_key)
      end

      private

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

            section.fields = section_config.fetch("fields").map do |field_key, field_config|
              type = field_config.fetch("type")
              raise ArgumentError, "Unknown content block type #{type.inspect} for #{page_key}.#{section_key}.#{field_key}" unless TYPES.include?(type)

              Field.new(key: field_key, label: field_config.fetch("label"), type: type, section: section)
            end

            section
          end

          page
        end
      end
    end
  end
end
