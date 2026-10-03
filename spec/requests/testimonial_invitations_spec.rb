require "rails_helper"

RSpec.describe "Testimonial invitations", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }
  let(:invitation) { TestimonialInvitation.create!(recipient_label: "Klientka z konsultacji") }

  def submit_opinion(invitation, quote: "Bardzo pomocna rozmowa", author: "Mama dwulatka", consent: "1", locale: nil)
    patch testimonial_invitation_path(invitation.token, locale: locale), params: {
      testimonial_invitation: { quote: quote, author: author, publication_consent: consent }
    }
  end

  it "keeps the private form inaccessible without a valid token and shows it in both languages" do
    get testimonial_invitation_path("invalid")
    expect(response).to have_http_status(:not_found)

    get testimonial_invitation_path(invitation.token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dodaj opinię", "Polityka prywatności")

    get testimonial_invitation_path(invitation.token, locale: :en)
    expect(response.body).to include("Share a testimonial", "Privacy policy")
  end

  it "accepts a consented opinion once and leaves it unpublished for moderation" do
    expect { submit_opinion(invitation) }.not_to change(ContentItem, :count)
    expect(response).to redirect_to(testimonial_invitation_path(invitation.token))
    expect(invitation.reload.status).to eq("submitted")
    expect(invitation.consented_at).to be_present

    get testimonial_invitation_path(invitation.token)
    expect(response.body).to include("Dziękujemy za opinię")
    expect(response.body).not_to include("Bardzo pomocna rozmowa")

    submit_opinion(invitation, quote: "Druga próba")
    expect(response).to have_http_status(:gone)
    expect(invitation.reload.quote).to eq("Bardzo pomocna rozmowa")
  end

  it "requires publication consent and a nonblank quote and signature" do
    submit_opinion(invitation, quote: " ", author: " ", consent: "0")
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Zgoda na publikację jest wymagana")
    expect(invitation.reload.status).to eq("open")
  end

  it "lets only an admin generate links and approve a submitted opinion into the CMS" do
    get admin_testimonial_invitations_path
    expect(response).to redirect_to(new_user_session_path)

    sign_in admin
    expect {
      post admin_testimonial_invitations_path, params: { recipient_label: "Nowa klientka" }
    }.to change(TestimonialInvitation, :count).by(1)
    created = TestimonialInvitation.last
    get admin_testimonial_invitations_path
    expect(response.body).to include(testimonial_invitation_url(created.token, locale: nil))

    submit_opinion(invitation)
    expect {
      post approve_admin_testimonial_invitation_path(invitation)
    }.to change(ContentItem, :count).by(1)
    expect(invitation.reload.status).to eq("approved")
    item = invitation.published_content_item
    expect(item.value_for("quote", :pl)).to eq("Bardzo pomocna rozmowa")
    expect(item.value_for("author", :pl)).to eq("Mama dwulatka")

    post approve_admin_testimonial_invitation_path(invitation)
    expect(ContentItem.where(collection_key: "testimonials.entries").count).to eq(1)

    get root_path
    expect(response.body).to include("Bardzo pomocna rozmowa")
  end

  it "allows rejection and never publishes a rejected opinion" do
    sign_in admin
    submit_opinion(invitation)
    expect {
      post decline_admin_testimonial_invitation_path(invitation)
    }.not_to change(ContentItem, :count)
    expect(invitation.reload.status).to eq("declined")
    post approve_admin_testimonial_invitation_path(invitation)
    expect(invitation.reload.published_content_item).to be_nil
  end

  it "publishes English submissions in English only" do
    sign_in admin
    submit_opinion(invitation, quote: "Helpful conversation", author: "Parent", locale: :en)
    post approve_admin_testimonial_invitation_path(invitation)

    get root_path(locale: :en)
    expect(response.body).to include("Helpful conversation")
    get "/"
    expect(response.body).not_to include("Helpful conversation")
  end
end
