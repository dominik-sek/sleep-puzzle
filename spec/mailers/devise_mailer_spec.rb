require 'rails_helper'

# The reset mail is the one screen in this flow nobody sees while developing, and
# it shipped as bare unstyled English from a placeholder sender address.
RSpec.describe "Devise mailer", type: :mailer do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  def reset_mail
    user.send_reset_password_instructions
    ActionMailer::Base.deliveries.last
  end

  before { ActionMailer::Base.deliveries.clear }

  # MAIL_FROM reaches a local run through .env, and CI has no .env, so asserting
  # on the ambient sender passed here and failed there. Pin it instead: what this
  # spec can honestly own is that ApplicationMailer reads MAIL_FROM at delivery
  # time, not that whoever runs the suite has configured a real address.
  describe "the sender" do
    before { stub_const("ENV", ENV.to_h.merge("MAIL_FROM" => "hello@sleep-puzzle.test")) }

    it "sends at all, from the configured address" do
      mail = reset_mail

      expect(mail).to be_present
      expect(mail.to).to eq([ user.email ])
      expect(mail.from.first).to eq("hello@sleep-puzzle.test")
    end

    # The devise generator ships `please-change-me@example.com`; the guard against
    # that one is worth keeping whether or not MAIL_FROM is set.
    it "is never the devise generator's placeholder" do
      stub_const("ENV", ENV.to_h.except("MAIL_FROM"))

      expect(reset_mail.from.first).not_to include("please-change-me")
    end
  end

  it "uses a Polish subject" do
    expect(reset_mail.subject).to eq("Ustaw nowe hasło")
  end

  it "carries the reset link with the token" do
    mail = reset_mail

    expect(mail.body.encoded).to match(%r{/users/password/edit\?[^"]*reset_password_token=})
  end

  # parent_mailer = ApplicationMailer is what supplies this; without it Devise
  # renders a bare fragment with no layout
  it "renders inside the app's mail layout" do
    body = reset_mail.body.encoded

    expect(body).to include("sleep.puzzle")
    expect(body).to include("Sleep Puzzle")
  end

  it "says how long the link lasts and what to do if it was not you" do
    body = reset_mail.body.encoded

    expect(body).to include("6")
    expect(body).to include("zignoruj")
  end

  it "follows the locale" do
    mail = I18n.with_locale(:en) do
      user.send_reset_password_instructions
      ActionMailer::Base.deliveries.last
    end

    expect(mail.subject).to eq("Reset password instructions")
    expect(mail.body.encoded).to include("Set a new password")
  end

  # The body followed the locale long before the links did: a mail renders with no
  # request in scope, so every URL in it fell back to the routes-level `locale: nil`
  # and came out Polish. An English reset mail's button opened the Polish password
  # form for anyone whose session had gone — a cleared cookie, another browser, a
  # link opened days later. ApplicationMailer#default_url_options is what fixes it.
  describe "the link in the mail" do
    it "carries the locale when the mail is English" do
      mail = I18n.with_locale(:en) do
        user.send_reset_password_instructions
        ActionMailer::Base.deliveries.last
      end

      expect(mail.body.encoded).to match(%r{/users/password/edit\?[^"]*locale=en})
    end

    # Polish is the default, so it is the bare path — the same one canonical
    # address the public site uses
    it "leaves a Polish mail's link unprefixed" do
      expect(reset_mail.body.encoded).not_to include("locale=")
    end
  end
end
