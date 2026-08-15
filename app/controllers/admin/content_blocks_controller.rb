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
      @pages = ContentBlock::Registry.pages
      @blocks = ContentBlock.declared.with_bodies.index_by(&:key)
    end

    def update
      section = ContentBlock::Registry.sections.find { |candidate| candidate.full_key == params[:section] }
      return head :not_found if section.nil?

      ContentBlock.transaction { save_section(section) }

      redirect_to admin_content_blocks_path(anchor: "section-#{section.page.key}-#{section.key}"),
                  notice: "Zapisano „#{section.label}”."
    end

    private

    def save_section(section)
      values = field_params(section)

      section.fields.each do |field|
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

    # Only the fields the registry says belong to this section are permitted, so
    # a forged form cannot reach a block on another page.
    def field_params(section)
      allowed = section.fields.to_h { |field| [ field.key, [ :pl, :en ] ] }

      params.fetch(:fields, ActionController::Parameters.new).permit(allowed)
    end
  end
end
