# == Schema Information
#
# Table name: bookings
#
#  id         :bigint           not null, primary key
#  name       :string
#  starts_at  :datetime
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer
#
class Booking < ApplicationRecord
  validates :name, presence: true
  validates :starts_at, presence: true
end
