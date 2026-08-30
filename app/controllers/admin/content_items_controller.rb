# frozen_string_literal: true

module Admin
  # Add and remove entries in an owner-managed list. The values themselves are
  # saved with the section form; this only controls how many entries there are.
  class ContentItemsController < BaseController
    def create
      collection = ContentBlock::Registry.collection(params[:collection_key])
      return head :not_found if collection.nil?

      # An unsynced collection renders from its declared defaults, so appending to
      # an empty table would swap the whole list for one blank row. Materialise
      # first, then add to what is now actually there.
      ContentItem.materialise_defaults!(collection)

      next_position = (ContentItem.for_collection(collection.full_key).maximum(:position) || 0) + 1
      ContentItem.create!(collection_key: collection.full_key, position: next_position)

      redirect_to_section(collection.section, "Dodano: #{collection.item_label.downcase}.")
    end

    def destroy
      item = ContentItem.find(params[:id])
      section = item.collection&.section
      item.destroy!

      redirect_to_section(section, "Usunięto element.")
    end

    private

    # ?open= rather than an anchor: Turbo follows the redirect with fetch, which
    # strips the fragment, so the section has to be reopened server-side.
    def redirect_to_section(section, notice)
      redirect_to admin_content_blocks_path(open: section&.full_key), notice: notice
    end
  end
end
