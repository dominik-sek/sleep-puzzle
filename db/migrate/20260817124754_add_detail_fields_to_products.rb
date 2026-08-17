class AddDetailFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    # An integer rather than "42 min": a number reads the same in both languages,
    # the same reasoning as packages.duration. The view formats it through
    # I18n so the unit can be translated on its own.
    #
    # The long description and the "co dostajesz" bullets are translated, so they
    # live in the `translations` jsonb and need no columns here.
    add_column :products, :length_minutes, :integer
  end
end
