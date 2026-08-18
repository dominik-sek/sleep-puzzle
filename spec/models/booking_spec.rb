require 'rails_helper'

# == Schema Information
#
# Table name: bookings
#
#  id                    :bigint           not null, primary key
#  confirmed_at          :datetime
#  email                 :string           default(""), not null
#  name                  :string
#  starts_at             :datetime
#  status                :integer          default(0), not null
#  token                 :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  calendar_event_id     :string
#  package_id            :integer          not null
#  paddle_transaction_id :string
#  user_id               :bigint           not null
#
# Indexes
#
#  index_bookings_on_package_id             (package_id)
#  index_bookings_on_paddle_transaction_id  (paddle_transaction_id) UNIQUE
#  index_bookings_on_starts_at_and_status   (starts_at,status)
#  index_bookings_on_token                  (token) UNIQUE
#  index_bookings_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (package_id => packages.id)
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe Booking, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
