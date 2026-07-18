# == Schema Information
#
# Table name: bookings
#
#  id         :bigint           not null, primary key
#  email      :string           default(""), not null
#  name       :string
#  starts_at  :datetime
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer          not null
#
# Indexes
#
#  index_bookings_on_package_id  (package_id)
#
# Foreign Keys
#
#  fk_rails_...  (package_id => packages.id)
#
class Booking < ApplicationRecord
  belongs_to :package

  validates :name, presence: true
  validates :starts_at, presence: true
  validates :email, presence: true
  validates :email, format: { with: Devise.email_regexp }

end
