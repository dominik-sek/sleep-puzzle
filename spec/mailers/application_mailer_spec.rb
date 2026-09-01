require 'rails_helper'

RSpec.describe ApplicationMailer do
  # MAIL_FROM ships from .env.production as a name that exists but is often
  # blank, and a blank from reaches Brevo as no sender at all.
  it "falls back to the default sender when MAIL_FROM is set but blank" do
    stub_const("ENV", ENV.to_h.merge("MAIL_FROM" => "", "OWNER_EMAIL" => "karola@example.com"))

    mail = ContactMailer.with(name: "Jan", email: "jan@example.com", body: "test").new_message

    expect(mail[:from].addrs.map(&:address)).to eq([ "kontakt@example.com" ])
  end

  it "uses MAIL_FROM when it is set" do
    stub_const("ENV", ENV.to_h.merge("MAIL_FROM" => "hello@sleep.test", "OWNER_EMAIL" => "karola@example.com"))

    mail = ContactMailer.with(name: "Jan", email: "jan@example.com", body: "test").new_message

    expect(mail[:from].addrs.map(&:address)).to eq([ "hello@sleep.test" ])
  end
end
