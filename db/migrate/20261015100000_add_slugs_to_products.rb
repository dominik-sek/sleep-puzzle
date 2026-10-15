require_relative "../../app/services/product_slug"

class AddSlugsToProducts < ActiveRecord::Migration[8.1]
  class ProductRecord < ActiveRecord::Base
    self.table_name = "products"
  end

  def up
    add_column :products, :slug, :string
    ProductRecord.reset_column_information
    backfill_slugs
    change_column_null :products, :slug, false
    add_index :products, :slug, unique: true
  end

  def down
    remove_column :products, :slug
  end

  def backfill_slugs
    used = Set.new
    ProductRecord.find_each(order: :asc) do |product|
      slug = ProductSlug.generate(product.translations, taken: ->(candidate) { used.include?(candidate) })
      product.update_columns(slug: slug)
      used.add(slug)
    end
  end
end
