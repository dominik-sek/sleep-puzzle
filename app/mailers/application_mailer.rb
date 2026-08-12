class ApplicationMailer < ActionMailer::Base
  # Procs rather than literals so a changed .env takes effect on boot without the
  # values being frozen into the class at load time.
  default from: -> { ENV.fetch("MAIL_FROM", "kontakt@example.com") },
          reply_to: -> { ENV["MAIL_REPLY_TO"].presence || ENV["OWNER_EMAIL"].presence }

  layout "mailer"
end
