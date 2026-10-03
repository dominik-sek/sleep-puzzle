class CreateTestimonialInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :testimonial_invitations do |t|
      t.string :token, null: false
      t.string :recipient_label, null: false
      t.string :status, null: false, default: "open"
      t.string :locale
      t.text :quote
      t.string :author
      t.datetime :consented_at
      t.datetime :submitted_at
      t.references :published_content_item, foreign_key: { to_table: :content_items, on_delete: :nullify }
      t.timestamps
    end

    add_index :testimonial_invitations, :token, unique: true
    add_index :testimonial_invitations, :status
  end
end
