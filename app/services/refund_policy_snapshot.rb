# Signed form copy preserves what the customer actually saw, even if CMS copy
# changes between rendering the form and submitting it. No client-supplied text.
class RefundPolicySnapshot
  class << self
    def build(kind, locale: I18n.locale)
      helper = ApplicationController.new.helpers
      {
        "kind" => kind.to_s,
        "locale" => locale.to_s,
        "consent" => helper.content_block("refunds.checkout.#{kind}_consent", locale: locale).to_s,
        "title" => helper.content_block("refunds.hero.title", locale: locale).to_s,
        "subject" => helper.content_block("refunds.checkout.confirmation_subject", locale: locale).to_s,
        "no_early_consent" => helper.content_block("refunds.notifications.no_early_consent", locale: locale).to_s,
        "clauses" => helper.content_items("refunds.clauses", locale: locale)
      }
    end

    def token(kind, locale: I18n.locale, snapshot: nil)
      verifier.generate(snapshot || build(kind, locale: locale), expires_in: 2.hours)
    end

    def verify(token, kind:)
      snapshot = verifier.verified(token.to_s)
      snapshot if snapshot && snapshot["kind"] == kind.to_s && snapshot["locale"].in?(%w[pl en])
    end

    private

    def verifier
      Rails.application.message_verifier("refund_policy")
    end
  end
end
