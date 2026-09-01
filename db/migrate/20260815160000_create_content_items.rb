class CreateContentItems < ActiveRecord::Migration[8.1]
  def change
    create_table :content_items do |t|
      # the section that owns the collection, e.g. "home.process"
      t.string :collection_key, null: false
      t.integer :position, null: false, default: 0
      # { "title" => { "pl" => "...", "en" => "..." } } - the item's declared
      # fields, per locale. Items hold short strings, so unlike ContentBlock
      # there is no Action Text here.
      t.jsonb :values, null: false, default: {}

      t.timestamps
    end

    add_index :content_items, [ :collection_key, :position ]
  end
end
