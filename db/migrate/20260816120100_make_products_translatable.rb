# The same move as MakePackagesTranslatable, for the audio products.
#
# `category` is left alone: it is an unused integer column with no declared
# meaning, and guessing one here would bake the guess into the data.
class MakeProductsTranslatable < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :translations, :jsonb, default: {}, null: false
    add_column :products, :position, :integer, default: 0, null: false
    add_column :products, :published, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE products
      SET translations = jsonb_strip_nulls(
        jsonb_build_object(
          'name', CASE WHEN name IS NULL THEN NULL ELSE jsonb_build_object('pl', name) END,
          'description', CASE WHEN description IS NULL THEN NULL ELSE jsonb_build_object('pl', description) END
        )
      )
    SQL

    execute "UPDATE products SET published = TRUE"
    execute "UPDATE products SET position = id"

    remove_column :products, :name
    remove_column :products, :description
  end

  def down
    add_column :products, :name, :string
    add_column :products, :description, :text

    execute <<~SQL.squish
      UPDATE products
      SET name = translations -> 'name' ->> 'pl',
          description = translations -> 'description' ->> 'pl'
    SQL

    remove_column :products, :translations
    remove_column :products, :position
    remove_column :products, :published
  end
end
