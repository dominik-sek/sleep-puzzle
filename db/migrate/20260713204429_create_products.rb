class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.integer :category
      t.integer :kind # audio/video
      t.text :description
      t.timestamps
    end
  end
end
