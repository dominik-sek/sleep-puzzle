class AddPaddlePriceIdToPurchasables < ActiveRecord::Migration[8.1]
  def change
    add_column :packages, :paddle_price_id, :string
    add_column :products, :paddle_price_id, :string
  end
end
