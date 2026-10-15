class CreateProductSlugHistories < ActiveRecord::Migration[8.1]
  def up
    create_table :product_slug_histories do |t|
      t.references :product, null: false, foreign_key: true
      t.string :slug, null: false
      t.timestamps
    end
    add_index :product_slug_histories, :slug, unique: true

    # Reserve existing addresses as well as future ones in one unique namespace.
    execute <<~SQL
      INSERT INTO product_slug_histories (product_id, slug, created_at, updated_at)
      SELECT id, slug, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM products
    SQL
  end

  def down
    drop_table :product_slug_histories
  end
end
