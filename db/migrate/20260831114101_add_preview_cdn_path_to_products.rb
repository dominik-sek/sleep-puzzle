class AddPreviewCdnPathToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :preview_cdn_path, :string
  end
end
