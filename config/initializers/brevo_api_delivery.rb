# frozen_string_literal: true

# `to_prepare` rather than a bare call: BrevoApiDelivery is autoloaded, and
# registering the class object once at boot would leave Action Mailer holding a
# stale copy after a reload in development.
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method :brevo_api, BrevoApiDelivery
end
