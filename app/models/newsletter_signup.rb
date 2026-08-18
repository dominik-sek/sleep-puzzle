# frozen_string_literal: true

# The one field of the newsletter form.
#
# Deliberately not a record, and for a stronger reason than ContactMessage: the
# list lives in Brevo, and a local copy of it would be a second consent record to
# keep in step with the one that actually governs — including on unsubscribe,
# which happens entirely on Brevo's side and never tells us.
#
# So this exists only to say whether what was typed is worth sending on.
class NewsletterSignup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string

  validates :email, presence: true
  # the same regexp the accounts use, so an address the site would accept as a
  # sign-up is not rejected here. allow_blank so an empty field says "podaj adres"
  # once rather than also complaining that nothing is not a valid address.
  validates :email, format: { with: Devise.email_regexp }, allow_blank: true

  # Trimmed on the way in: an address pasted with a trailing space would
  # otherwise fail the format check for no good reason.
  def email=(value)
    super(value&.strip)
  end
end
