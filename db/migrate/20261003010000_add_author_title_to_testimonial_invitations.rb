class AddAuthorTitleToTestimonialInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :testimonial_invitations, :author_title, :string
  end
end
