# == Schema Information
#
# Table name: consultation_weekly_slots
#
#  id                      :bigint           not null, primary key
#  minute_of_day           :integer          not null
#  weekday                 :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  consultation_setting_id :bigint           not null
#
# Indexes
#
#  index_consultation_weekly_slots_on_consultation_setting_id  (consultation_setting_id)
#
# Foreign Keys
#
#  fk_rails_...  (consultation_setting_id => consultation_settings.id)
#
class ConsultationWeeklySlot < ApplicationRecord
  belongs_to :consultation_setting, inverse_of: :weekly_slots
  validates :weekday, numericality: { only_integer: true, in: 0..6 }
  validates :minute_of_day, numericality: { only_integer: true, in: 0..1439 }

  def time_of_day
    return @invalid_time if defined?(@invalid_time)
    format("%02d:%02d", minute_of_day / 60, minute_of_day % 60) if minute_of_day
  end

  def time_of_day=(value)
    if value.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      remove_instance_variable(:@invalid_time) if defined?(@invalid_time)
      hours, minutes = value.split(":").map(&:to_i)
      self.minute_of_day = hours * 60 + minutes
    else
      @invalid_time = value
      self.minute_of_day = nil
    end
  end
end
