class ContactsController < ApplicationController
  # The surface the Turnstile widget is minted for. A token is issued against an
  # action, so naming it here - and checking it on the way back - means a token
  # taken from another form on the site cannot be spent on this one.
  TURNSTILE_ACTION = "contact".freeze

  # The one public endpoint that sends mail on an anonymous request, so a script
  # that finds it must not be able to keep the owner's inbox busy. Turnstile is
  # the front door; this is the backstop for anything that gets through it, and
  # for the window while Cloudflare is unreachable. Backed by Rails.cache; the
  # test environment's null store makes it a no-op there.
  rate_limit to: 5, within: 1.minute, only: :create, with: :too_many_messages

  def show
    @contact_message = ContactMessage.new
  end

  def create
    @contact_message = ContactMessage.new(contact_message_params)

    # gates the existing flow rather than replacing it: everything below runs
    # unchanged once the token checks out
    return render_form(t("contacts.turnstile_failed")) unless turnstile_verified?
    return render_form if @contact_message.invalid?

    # deliver_later so a mail outage retries on its own rather than showing the
    # sender an error for something already accepted. Handed over as plain
    # attributes because the message is not a record, and Active Job has no way
    # to serialize the object itself.
    ContactMailer.with(**@contact_message.attributes.symbolize_keys).new_message.deliver_later

    render partial: "contacts/sent"
  end

  private

  def turnstile_verified?
    TurnstileVerificationService.call(
      token: params["cf-turnstile-response"],
      action: TURNSTILE_ACTION,
      hostname: request.host,
      remote_ip: request.remote_ip
    ).verified?
  end

  # Always back into the frame the form was submitted from, so every way this can
  # go wrong says so where the visitor is looking rather than failing silently
  # inside a Turbo frame. A rejected submission also gets a newly rendered widget,
  # which it needs: the token it just spent cannot be replayed.
  def render_form(alert = nil, status: :unprocessable_entity)
    render partial: "contacts/form",
           locals: { contact_message: @contact_message, alert: alert },
           status: status
  end

  def too_many_messages
    @contact_message = ContactMessage.new(contact_message_params)

    render_form(t("contacts.rate_limited"), status: :too_many_requests)
  end

  # fetch rather than require: a POST with no params at all should come back as
  # "fill these in" on the form, not a bare 400
  def contact_message_params
    params.fetch(:contact_message, ActionController::Parameters.new).permit(:name, :email, :body)
  end
end
