class CreatePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :packages do |t|
      t.string :name
      t.integer :duration # in days?
      t.text :for_whom
      t.jsonb :core, default: {}
      t.jsonb :extra, default: {}
      t.timestamps
    end

    add_index :packages, :core, using: :gin
    add_index :packages, :extra, using: :gin
  end
end
