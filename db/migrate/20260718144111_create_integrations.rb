class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.string :service_name, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
    add_index :integrations, :service_name, unique: true
  end
end
