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
#  calendar_id   :string
#
# Indexes
#
#  index_integrations_on_service_name  (service_name) UNIQUE
#
class Integration < ApplicationRecord
  GOOGLE_CALENDAR = "google_calendar"

  encrypts :access_token, :refresh_token

  validates :service_name, presence: true, uniqueness: true

  def self.google_calendar
    find_by(service_name: GOOGLE_CALENDAR)
  end

  # Which of the owner's calendars bookings are written to. Picked in the panel;
  # GOOGLE_CALENDAR_ID is only the pre-panel fallback and can go once a calendar
  # has been selected there.
  def self.google_calendar_id
    google_calendar&.calendar_id.presence || ENV["GOOGLE_CALENDAR_ID"].presence
  end
end
