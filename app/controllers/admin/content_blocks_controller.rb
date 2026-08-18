# frozen_string_literal: true

module Admin
  # One screen for the whole CMS: a tree of pages > sections > fields on the left,
  # and an accordion of editable sections on the right. There is no create or
  # destroy — the set of blocks comes from config/content_blocks.yml.
  #
  # Each section is its own form, so saving one leaves the rest of the page (and
  # any half-finished edit in another section) alone.
  class ContentBlocksController < BaseController
    def index
      # Which section to render expanded. A query param rather than a URL
      # fragment: Turbo follows a redirect with fetch, and fetch strips the
      # fragment, so an anchor never survives the round trip.
      @open_section = ContentBlock::Registry.section(params[:open])
      @pages = ContentBlock::Registry.pages
      @blocks = ContentBlock.declared.with_bodies.index_by(&:key)
      @items = ContentItem.declared.order(:position, :id).group_by(&:collection_key)
    end

    def update
      section = ContentBlock::Registry.sections.find { |candidate| candidate.full_key == params[:section] }
      return head :not_found if section.nil?

      problems = nil

      ContentBlock.transaction do
        save_section(section)
        save_items(section)
        problems = save_images(section)
      end

      # A rejected upload does not undo the copy that saved alongside it — the
      # text is fine, only the file was wrong — so this reports rather than rolls
      # back, and says which file and why.
      if problems.any?
        redirect_to admin_content_blocks_path(open: section.full_key), alert: problems.to_sentence
      else
        redirect_to admin_content_blocks_path(open: section.full_key),
                    notice: "Zapisano „#{section.label}”."
      end
    end

    private

    def save_section(section)
      values = field_params(section)

      section.fields.reject(&:image?).each do |field|
        submitted = values[field.key]
        next if submitted.nil?

        block = ContentBlock.find_by!(key: field.full_key)

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
      return if collection.nil? || submitted.blank?

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

        item.save!
      end
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

        block = ContentBlock.find_by!(key: field.full_key)

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
