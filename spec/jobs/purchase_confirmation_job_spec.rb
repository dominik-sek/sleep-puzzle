require "rails_helper"

RSpec.describe PurchaseConfirmationJob do
  let(:user) { User.create!(email: "receipt@example.com", password: "password123") }
  let(:order) { user.orders.create!(status: :paid, consent_accepted_at: Time.current, legal_snapshot: RefundPolicySnapshot.build(:audio), order_items: [ OrderItem.new(product: create_product) ]) }

  it "sends the saved policy only once, even after the policy changes" do
    saved = order.legal_snapshot["consent"]
    ContentBlock.create!(key: "refunds.checkout.audio_consent", value_pl: "Nowa zgoda")
    expect { 2.times { described_class.perform_now("order", order.id) } }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(order.reload.legal_confirmation_sent_at).to be_present
    expect(ActionMailer::Base.deliveries.last.text_part.body.decoded).to include(saved)
    expect(ActionMailer::Base.deliveries.last.text_part.body.decoded).not_to include("Nowa zgoda")
  end

  it "does not invent consent or send a new confirmation for legacy purchases" do
    order.update!(legal_snapshot: {}, consent_accepted_at: nil)
    expect { described_class.perform_now("order", order.id) }.not_to change { ActionMailer::Base.deliveries.size }
    expect(order.reload.legal_confirmation_sent_at).to be_nil
  end

  it "keeps an unsent confirmation pending after mail delivery fails" do
    allow(PurchaseMailer).to receive(:with).and_return(double(confirmed: double(deliver_now: -> { })))
    allow(PurchaseMailer.with(record: order).confirmed).to receive(:deliver_now).and_raise(Net::SMTPFatalError, "unavailable")
    described_class.perform_now("order", order.id)
    expect(order.reload.legal_confirmation_sent_at).to be_nil
  end
end
