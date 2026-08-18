# == Schema Information
#
# Table name: integrations
#
#  id            :bigint           not null, primary key
#  access_token  :text
#  expires_at    :datetime
#  refresh_token :text
#  service_name  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_integrations_on_service_name  (service_name) UNIQUE
#
class Integration < ApplicationRecord
  GOOGLE_CALENDAR = "google_calendar"

  encrypts :access_token, :refresh_token

  validates :service_name, presence: true, uniqueness: true
end
