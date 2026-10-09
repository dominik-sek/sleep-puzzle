class AddPaddleAdjustmentHistory < ActiveRecord::Migration[8.1]
  def change
    add_column :paddle_adjustments, :events, :jsonb, default: [], null: false
  end
end
