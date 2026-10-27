require "rails_helper"

RSpec.describe "Accessible form contracts", type: :request do
  def document
    Nokogiri::HTML(response.body)
  end

  def expect_descriptions_to_resolve
    document.css("[aria-describedby]").each do |control|
      control["aria-describedby"].split.each do |id|
        expect(document.at_css("[id='#{id}']")).to be_present, "Missing description #{id}"
      end
    end
  end

  it "connects registration requirements and validation errors to their fields" do
    get new_user_registration_path
    expect(document.at_css("#user_password")["aria-describedby"]).to include("user_password_hint")
    expect(document.at_css("#user_password_hint")["class"]).to include("text-taupe")
    expect_descriptions_to_resolve

    post user_registration_path, params: { user: { email: "bad", password: "x", password_confirmation: "y" } }
    expect(document.at_css("#user_password")["aria-invalid"]).to eq("true")
    expect(document.at_css("#user_password")["aria-describedby"]).to include("user_password_error")
    expect(document.at_css("#error_explanation[role='alert']")).to be_present
    expect_descriptions_to_resolve
  end

  it "labels every catalogue and article editor control and declares Polish" do
    sign_in User.create!(email: "accessible-admin@example.com", password: "password123", admin: true)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
    [ new_admin_product_path, new_admin_package_path, new_admin_article_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(document.at_css("html")["lang"]).to eq("pl")
      expect(document.at_css("body")["data-locale-tag-value"]).to eq("pl")
      document.css("input, textarea, select, trix-editor").each do |control|
        next if %w[hidden submit checkbox].include?(control["type"])
        label = document.at_css("label[for='#{control['id']}']")
        expect(label.present? || control["aria-label"].present?).to be(true), "Unlabelled #{control['id']} on #{path}"
      end
      expect_descriptions_to_resolve
    end
  end

  it "connects testimonial validation and retains help after a rejected submission" do
    invitation = TestimonialInvitation.create!(recipient_label: "Test")
    patch testimonial_invitation_path(invitation.token), params: {
      testimonial_invitation: { quote: "", author: "", publication_consent: "0" }
    }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(document.at_css("#testimonial_invitation_quote")["aria-invalid"]).to eq("true")
    expect(document.at_css("#testimonial_invitation_author")["aria-describedby"]).to include("testimonial-author-hint", "testimonial-author-error")
    expect(document.at_css("[role='alert']")).to be_present
    expect_descriptions_to_resolve
  end

  it "connects booking errors to editable fields and announces rejected data" do
    sign_in User.create!(email: "accessible-buyer@example.com", password: "password123")
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    post bookings_path, params: { booking: { name: "", package_id: "", date: Date.current.next_occurring(:monday).iso8601, hour: "08:15" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(document.at_css("turbo-frame#booking_form")["aria-live"]).to eq("polite")
    expect(document.at_css("#booking_name")["aria-invalid"]).to eq("true")
    expect(document.at_css("#booking_name")["required"]).to be_present
    expect(document.at_css("#booking_package_id")["aria-describedby"]).to eq("booking_package_id_error")
    expect_descriptions_to_resolve
  end
end
