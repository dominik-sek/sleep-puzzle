# frozen_string_literal: true

# What someone types into the contact form.
#
# Deliberately not a record: the page's whole job is to reach the owner's inbox,
# and a stored copy would be a second place to check that adds nothing the mail
# doesn't already carry. So this validates the input and is handed to the mailer.
class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  # long enough for anyone describing their situation, short enough that the form
  # can't be used to post a payload at the inbox
  BODY_LIMIT = 5_000

  attribute :name, :string
  attribute :email, :string
  attribute :body, :string

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true
  # allow_blank so an empty field says "podaj adres" once rather than also
  # complaining that nothing is not a valid address
  validates :email, format: { with: Devise.email_regexp }, allow_blank: true
  validates :body, presence: true, length: { maximum: BODY_LIMIT }

  # Trimmed on the way in: a trailing space in a name is not worth an error, and
  # an address with one would fail the format check for no good reason.
  def name=(value)
    super(value&.strip)
  end

  def email=(value)
    super(value&.strip)
  end
end
