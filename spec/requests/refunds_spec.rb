require "rails_helper"

RSpec.describe "Refunds and consent", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { User.create!(email: "refund@example.com", password: "password123") }
  let(:product) { create_product }

  it "renders both languages and editable policy copy" do
    get refunds_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("24 godziny", "paddle.net")
    ContentBlock.create!(key: "refunds.hero.title", value_pl: "Moje zasady", value_en: "My terms")
    get refunds_path
    expect(response.body).to include("Moje zasady")
    get refunds_path(locale: :en)
    expect(response.body).to include("My terms", "24 hours")
  end

  it "rejects checkout without consent and preserves the basket" do
    sign_in user
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    post cart_items_path, params: { product_id: product.id }
    expect { post orders_path, params: { policy_token: RefundPolicySnapshot.token(:audio) } }.not_to change(Order, :count)
    expect(response).to redirect_to(cart_path)
    expect(Cart.from_session(session, owner: user).lines.map(&:product)).to eq([ product ])
  end

  it "keeps the consent text actually shown before a CMS edit" do
    sign_in user
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    allow_any_instance_of(User).to receive(:payment_processor).and_return(double(api_record: double(id: "ctm_test")))
    post cart_items_path, params: { product_id: product.id }
    snapshot = RefundPolicySnapshot.build(:audio)
    token = RefundPolicySnapshot.token(:audio, snapshot: snapshot)
    ContentBlock.create!(key: "refunds.checkout.audio_consent", value_pl: "Nowa treść")
    post orders_path, params: { policy_token: token, digital_content_consent: "1" }
    expect(Order.sole.legal_snapshot["consent"]).to eq(snapshot["consent"])
    expect(Order.sole.consent_accepted_at).to be_present
    expect(RefundPolicySnapshot.build(:audio)["consent"]).to eq("Nowa treść")
  end

  it "rejects forged and expired policy tokens" do
    expect(RefundPolicySnapshot.verify("forged", kind: :audio)).to be_nil
    token = RefundPolicySnapshot.token(:audio)
    travel_to 3.hours.from_now do
      expect(RefundPolicySnapshot.verify(token, kind: :audio)).to be_nil
    end
  end

  describe "playback tracking" do
    let!(:item) { user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: product) ]).order_items.sole }
    before do
      sign_in user
      allow(BunnySignedUrlService).to receive(:configured?).and_return(true)
      allow(BunnySignedUrlService).to receive(:call).and_return("https://audio.example.com/audio.mp3?token=signed")
    end

    it "does not record playback on page load or issuance of a stream" do
      get dashboard_index_path
      expect(item.reload.first_played_at).to be_nil
      get stream_product_path(product, order_item_id: item.id)
      expect(response).to have_http_status(:redirect)
      expect(item.reload.first_stream_issued_at).to be_present
      expect(item.first_played_at).to be_nil
    end

    it "uses server time and preserves the first playing event" do
      get stream_product_path(product, order_item_id: item.id)
      post playback_order_item_path(item), params: { first_played_at: "2000-01-01" }
      expect(response).to have_http_status(:no_content)
      first = item.reload.first_played_at
      expect(first).to be_within(2.seconds).of(Time.current)
      travel_to 1.hour.from_now do
        post playback_order_item_path(item)
        expect(item.reload.first_played_at).to eq(first)
      end
    end

    it "refuses playback evidence before issuance and for someone else's purchase" do
      post playback_order_item_path(item)
      expect(response).to have_http_status(:forbidden)
      other = User.create!(email: "other@example.com", password: "password123")
      sign_in other
      post playback_order_item_path(item)
      expect(response).to have_http_status(:not_found)
      expect(item.reload.first_played_at).to be_nil
    end

    it "refuses new stream issuance and playback after a full refund" do
      item.update!(refunded_at: Time.current)
      get stream_product_path(product, order_item_id: item.id)
      expect(response).to have_http_status(:forbidden)
      post playback_order_item_path(item)
      expect(response).to have_http_status(:not_found)
    end

    it "counts a paid chapter toward its purchased audio process" do
      process = create_product(kind: :audio_process, name: "Audioproces")
      process_item = user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: process) ]).order_items.sole
      get stream_chapter_product_path(process, chapter_id: process.audio_chapters.sole.id, order_item_id: process_item.id)
      expect(response).to have_http_status(:redirect)
      post playback_order_item_path(process_item)
      expect(process_item.reload.first_played_at).to be_present
      expect(item.reload.first_played_at).to be_nil
    end

    it "does not count free previews, trailers or failed stream issuance" do
      product.update_columns(preview_cdn_path: "/preview.mp3")
      get preview_product_path(product)
      expect(response).to have_http_status(:redirect)
      process = create_product(kind: :audio_process)
      process.update_columns(trailer_cdn_path: "/trailer.mp4")
      process_item = user.orders.create!(status: :paid, order_items: [ OrderItem.new(product: process) ]).order_items.sole
      get trailer_product_path(process)
      expect(response).to have_http_status(:redirect)
      expect(process_item.reload.first_stream_issued_at).to be_nil
      allow(BunnySignedUrlService).to receive(:call).and_return(nil)
      get stream_product_path(product, order_item_id: item.id)
      expect(response).to have_http_status(:not_found)
      expect(item.reload.first_stream_issued_at).to be_nil
      expect(item.first_played_at).to be_nil
      expect(process_item.first_played_at).to be_nil
    end
  end
end
