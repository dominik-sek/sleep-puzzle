class AddPlainValuesToContentBlocks < ActiveRecord::Migration[8.1]
  def change
    # plain fields (titles, labels) live here; rich fields use Action Text
    add_column :content_blocks, :value_pl, :text
    add_column :content_blocks, :value_en, :text
  end
end
