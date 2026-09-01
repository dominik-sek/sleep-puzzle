class AddIconToProducts < ActiveRecord::Migration[8.1]
  def change
    # The design gives every product its own emoji on the card and in the cart -
    # 🌙 for one audio process, ☀️ for another - so it cannot be derived from
    # `kind`. Nullable: Product#display_icon falls back per kind, so a product
    # added without one still renders.
    add_column :products, :icon, :string
  end
end
