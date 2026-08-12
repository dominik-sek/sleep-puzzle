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
class Booking < ApplicationRecord
  belongs_to :package
  belongs_to :user

  has_secure_token

  enum :status, { pending: 0, confirmed: 1, payment_failed: 2, canceled: 3 }

  # shown on the success page and written onto the Google Calendar event
  PAYMENT_STATUS_LABELS = {
    "pending" => "Oczekuje na płatność",
    "confirmed" => "Opłacona",
    "payment_failed" => "Płatność nieudana",
    "canceled" => "Anulowana"
  }.freeze

  validates :name, presence: true
  validates :starts_at, presence: true
  validates :email, presence: true
  # only when it's actually being set. A booking whose stored address predates a
  # stricter regexp must still be able to change status — otherwise confirming a
  # real payment, or releasing the slot, raises on an unrelated legacy value.
  validates :email, format: { with: Devise.email_regexp }, if: :email_changed?

  def to_param
    token
  end

  # Called from BookingConfirmationService when Paddle reports the transaction paid.
  # The unique index on paddle_transaction_id is what actually keeps redelivered
  # webhooks from confirming twice, so treat a violation as "already handled".
  def confirm_payment!(transaction_id)
    update!(status: :confirmed, confirmed_at: Time.current, paddle_transaction_id: transaction_id)
    broadcast_status
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def fail_payment!(status)
    update!(status: status)
    broadcast_status
  end

  private

  # the buyer is sitting on bookings#show waiting for exactly this
  def broadcast_status
    broadcast_replace_to self, target: "booking_status", partial: "bookings/status", locals: { booking: self }
  end
end
