class NewsletterSubscriptionsController < ApplicationController
  # The second public endpoint that reaches an outside service on an anonymous
  # request, so a script that finds it must not be able to spend the Brevo quota
  # or use it to probe which addresses are already on the list. Deliberately
  # tighter than the contact form's five: nobody subscribes twice in a minute.
  #
  # No Turnstile here, unlike the contact form. That one puts mail in the owner's
  # inbox on every submission; this one hands an address to Brevo, which sends a
  # confirmation nobody can act on but the address's owner - so the rate limit is
  # the proportionate control, and a challenge on a one-field box in the middle
  # of the home page is not.
  rate_limit to: 3, within: 1.minute, only: :create, with: :too_many_signups

  def create
    @signup = NewsletterSignup.new(signup_params)

    return render_form if @signup.invalid?
    return render_form(t("newsletter.failed")) unless subscribed?

    render partial: "newsletter_subscriptions/subscribed"
  end

  private

  # Brevo sends them back to the home page once they follow the link in the
  # confirmation mail - in the language they signed up in, which is why it is
  # built here rather than fixed in the service.
  def subscribed?
    BrevoSubscriptionService.call(
      email: @signup.email,
      redirect_url: root_url
    ).subscribed?
  end

  # Always back into the frame the form was submitted from, so every way this can
  # go wrong says so where the visitor is looking rather than failing silently
  # inside a Turbo frame.
  def render_form(alert = nil, status: :unprocessable_entity)
    render partial: "newsletter_subscriptions/form",
           locals: { signup: @signup, alert: alert },
           status: status
  end

  def too_many_signups
    @signup = NewsletterSignup.new(signup_params)

    render_form(t("newsletter.rate_limited"), status: :too_many_requests)
  end

  # fetch rather than require: a POST with no params at all should come back as
  # "fill this in" on the form, not a bare 400
  def signup_params
    params.fetch(:newsletter_signup, ActionController::Parameters.new).permit(:email)
  end
end
