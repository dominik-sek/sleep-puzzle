# frozen_string_literal: true

require "cgi"

module Admin
  # The registry supplies navigation and the selected section's editor. Keeping
  # one form on screen makes long copy, images and collections usable on a laptop.
  class ContentBlocksController < BaseController
    def index
      @pages = ContentBlock::Registry.pages
      requested_section = ContentBlock::Registry.section(params[:open])
      requested_page = @pages.find { |page| page.key == params[:page] }
      page = requested_section && !requested_section.admin_hidden? ? requested_section.page : requested_page || @pages.first
      @open_section = requested_section unless requested_section&.admin_hidden?
      @open_section ||= page.sections.find { |section| !section.admin_hidden? }
      @editor_locale = editor_locale
      @blocks = ContentBlock.declared.with_bodies.index_by(&:key)
      @items = ContentItem.declared.order(:position, :id).group_by(&:collection_key)
      @preview_page = @open_section&.page&.key || page.key
      @preview_data = @pages.to_h do |page|
        [ page.key, ContentBlock::LOCALES.to_h do |locale|
          [ locale, {
            url: helpers.content_preview_path(page.key, locale: locale),
            entries: preview_entries(page, locale)
          } ]
        end ]
      end
    end

    def update
      section = ContentBlock::Registry.sections.find { |candidate| candidate.full_key == params[:section] }
      return head :not_found if section.nil?

      problems = nil

      ContentBlock.transaction do
        save_section(section)
        item_problems = save_items(section)
        problems = item_problems + save_images(section)
      end

      # A rejected upload does not undo the copy that saved alongside it - the
      # text is fine, only the file was wrong - so this reports rather than rolls
      # back, and says which file and why.
      if problems.any?
        redirect_to section_path(section), alert: problems.to_sentence
      else
        redirect_to section_path(section), notice: "Zapisano „#{section.label}”."
      end
    rescue ActiveRecord::RecordInvalid => error
      redirect_to section_path(section),
                  alert: "Nie udało się zapisać „#{section.label}”: #{error.record.errors.full_messages.to_sentence}"
    end

    private

    def editor_locale
      params[:lang] == "en" ? "en" : "pl"
    end

    def section_path(section)
      admin_content_blocks_path(open: section.full_key, **(editor_locale == "en" ? { lang: "en" } : {}))
    end

    def preview_entries(page, locale)
      sections = page.key == "footer" ? [ page ] : [ page, @pages.find { |candidate| candidate.key == "footer" } ].compact

      sections.flat_map do |source_page|
        source_page.sections.reject(&:admin_hidden?).flat_map do |section|
          fields = section.fields.reject { |field| field.image? || field.admin_hidden? }.filter_map do |field|
            value = @blocks[field.full_key]&.value_for(locale) || field.default_for(locale)
            next if value.blank?

            { key: field.full_key, section: section.full_key,
              type: field.type, text: preview_text(value),
              defaults: ContentBlock::LOCALES.to_h do |language|
                [ language, preview_text(field.default_for(language)) ]
              end }
          end

          collection = section.collection
          next fields unless collection

          values = @items[section.full_key].presence&.map { |item| item.to_values(locale) } || collection.default_items(locale)
          fields + values.flat_map do |item|
            collection.fields.filter_map do |field|
              text = item[field.key].to_s.squish
              { section: section.full_key, text: text } if text.present?
            end
          end
        end
      end
    end

    def preview_text(value)
      CGI.unescapeHTML(helpers.strip_tags(value.to_s)).squish
    end

    # A declared field may have no row yet: nothing runs content_blocks:sync on
    # deploy, and the panel builds its tree from the registry rather than from
    # rows, so the owner can reach a field that was never synced. find_by! turned
    # that into a 404 that rolled back every other edit in the section. The key
    # comes from the registry here, and ContentBlock validates that on create.
    def block_for(field)
      ContentBlock.find_or_create_by!(key: field.full_key)
    end

    def save_section(section)
      values = field_params(section)

      section.fields.reject(&:image?).each do |field|
        submitted = values[field.key]
        next if submitted.nil?

        block = block_for(field)

        if field.rich?
          block.update!(body_pl: submitted[:pl], body_en: submitted[:en])
        else
          block.update!(value_pl: submitted[:pl], value_en: submitted[:en])
        end
      end
    end

    # Item values are read key by key from the registry's own declaration rather
    # than mass-assigned, so a forged form cannot write anything that is not a
    # declared field of this section's collection.
    def save_items(section)
      collection = section.collection
      submitted = params[:items]
      return [] if collection.nil? || submitted.blank?

      problems = []

      ContentItem.for_collection(collection.full_key).each do |item|
        attributes = submitted[item.id.to_s]
        next if attributes.blank?

        item.position = attributes[:position] if attributes[:position].present?

        collection.fields.each do |field|
          ContentItem::LOCALES.each do |locale|
            value = attributes.dig(:values, field.key, locale.to_s)
            item.assign_value(field.key, locale, value) unless value.nil?
          end
        end

        if collection.full_key == "testimonials.entries"
          if attributes[:remove_avatar] == "1"
            item.avatar.purge_later
          elsif (file = attributes[:avatar]).present?
            problem = avatar_rejection_for(file)
            problem ? problems << problem : item.avatar = file
          end
        end

        item.save!
      end

      problems
    end

    def avatar_rejection_for(file)
      unless file.content_type.in?(ContentBlock::IMAGE_CONTENT_TYPES)
        return "„#{file.original_filename}” nie jest obsługiwanym obrazem (PNG, JPG, WEBP, AVIF)"
      end

      return unless file.size > ContentBlock::IMAGE_MAX_BYTES

      "„#{file.original_filename}” jest za duży (limit #{helpers.number_to_human_size(ContentBlock::IMAGE_MAX_BYTES)})"
    end

    # Uploads, read key by key from the registry the same way item values are, so
    # a forged form cannot attach a file to a block on another page.
    #
    # Returns the messages for any file that was refused.
    def save_images(section)
      submitted = params[:images]
      return [] if submitted.blank?

      section.fields.select(&:image?).filter_map do |field|
        attributes = submitted[field.key]
        next if attributes.blank?

        block = block_for(field)

        if attributes[:remove] == "1"
          block.image.purge_later
          next
        end

        file = attributes[:file]
        next if file.blank?

        rejection_for(file) || attach_image(block, file)
      end
    end

    # Checked before attaching rather than validated after: a rejected upload
    # should leave no half-written attachment behind to clean up.
    def rejection_for(file)
      unless file.content_type.in?(ContentBlock::IMAGE_CONTENT_TYPES)
        return "„#{file.original_filename}” nie jest obsługiwanym obrazem (PNG, JPG, WEBP, AVIF)"
      end

      return unless file.size > ContentBlock::IMAGE_MAX_BYTES

      "„#{file.original_filename}” jest za duży (limit #{helpers.number_to_human_size(ContentBlock::IMAGE_MAX_BYTES)})"
    end

    def attach_image(block, file)
      block.image.attach(file)
      nil
    end

    # Only the fields the registry says belong to this section are permitted, so
    # a forged form cannot reach a block on another page.
    def field_params(section)
      allowed = section.fields.reject(&:image?).to_h { |field| [ field.key, [ :pl, :en ] ] }

      params.fetch(:fields, ActionController::Parameters.new).permit(allowed)
    end
  end
end
