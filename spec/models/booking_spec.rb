require 'rails_helper'

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
RSpec.describe Booking, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
