class ApplicationMailer < ActionMailer::Base
  # Procs rather than literals so a changed .env takes effect on boot without the
  # values being frozen into the class at load time.
  # .presence, not fetch's default: MAIL_FROM ships from .env.production as a
  # name that exists but is often blank, and fetch only falls back on a missing
  # key. A blank from reaches Brevo as no sender at all - a 400 on every mail.
  default from: -> { ENV["MAIL_FROM"].presence || "kontakt@example.com" },
          reply_to: -> { ENV["MAIL_REPLY_TO"].presence || ENV["OWNER_EMAIL"].presence }

  layout "mailer"

  # A mail is rendered with no request in scope, so without this every link in it
  # falls back to the routes-level `locale: nil` and comes out Polish - including
  # the links in a mail whose body was just translated into English. The reset
  # link was the case that mattered: an English mail whose button opened the
  # Polish password form for anyone whose session had since gone.
  #
  # `I18n.locale` is still the recipient's here. Devise delivers inline, in the
  # request's own thread; the booking and contact mails go through `deliver_later`,
  # and ActiveJob serialises the locale with the job and restores it around
  # `perform`, so the language survives the trip through the queue either way.
  #
  # Same shape as ApplicationController#default_url_options - only a non-default
  # locale is ever put in a URL, so Polish links stay bare. On a scoped route that
  # lands in the path (`/en/bookings/:token`), on an unscoped one as `?locale=en`.
  def default_url_options
    super.merge(locale: (I18n.locale unless I18n.locale == I18n.default_locale))
  end
end
