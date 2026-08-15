class CreateContentBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :content_blocks do |t|
      t.string :key, null: false

      t.timestamps
    end

    add_index :content_blocks, :key, unique: true
  end
end
