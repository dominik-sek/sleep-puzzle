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

  it "sends at all — the sender used to be the generator's placeholder" do
    mail = reset_mail

    expect(mail).to be_present
    expect(mail.to).to eq([ user.email ])
    expect(mail.from.first).not_to include("please-change-me")
    expect(mail.from.first).not_to include("example.com")
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
