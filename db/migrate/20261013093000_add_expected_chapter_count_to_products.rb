class AddExpectedChapterCountToProducts < ActiveRecord::Migration[8.1]
  def change
    # No backfill: the number of uploads is not proof of the promised program.
    # The owner must declare the full count before a new purchase is offered.
    add_column :products, :expected_chapter_count, :integer
    add_check_constraint :products,
                         "expected_chapter_count IS NULL OR expected_chapter_count > 0",
                         name: "products_expected_chapter_count_positive"
  end
end
