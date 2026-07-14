require 'rails_helper'

# == Schema Information
#
# Table name: bookings
#
#  id         :bigint           not null, primary key
#  date       :date
#  name       :string
#  status     :integer
#  time_slot  :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer
#
RSpec.describe Booking, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
