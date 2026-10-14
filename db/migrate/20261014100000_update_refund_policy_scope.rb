class UpdateRefundPolicyScope < ActiveRecord::Migration[8.1]
  class Block < ActiveRecord::Base
    self.table_name = "content_blocks"
  end

  class Item < ActiveRecord::Base
    self.table_name = "content_items"
  end

  def up
    replace_copy(:up)
  end

  def down
    replace_copy(:down)
  end

  private

  # Only replace unchanged shipped copy. Custom CMS edits and saved purchase
  # snapshots are not affected. The dated plan stays fixed for future migrations.
  def replace_copy(direction)
    plan = JSON.parse(File.read(File.expand_path("../../config/refund_policy_copy_20261014.json", __dir__)))
    expected_key, replacement_key = direction == :up ? %w[expected replacement] : %w[replacement expected]
    plan.fetch("blocks").each do |change|
      column = "value_#{change.fetch('locale')}"
      Block.where(key: change.fetch("key"), column => change.fetch(expected_key))
        .update_all(column => change.fetch(replacement_key), updated_at: Time.current)
    end
    plan.fetch("items").group_by { |change| change.fetch("collection") }.each do |collection, changes|
      Item.where(collection_key: collection).find_each do |item|
        values = item.values.deep_dup
        changes.each do |change|
          field, locale = change.values_at("field", "locale")
          next unless values.dig(field, locale) == change.fetch(expected_key)

          values.fetch(field)[locale] = change.fetch(replacement_key)
        end
        item.update!(values: values) if values != item.values
      end
    end
  end
end
