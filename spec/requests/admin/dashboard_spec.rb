require 'rails_helper'

RSpec.describe "Admin::Dashboard", type: :request do
  let(:password) { "password123" }

  def create_user(email:, admin: false)
    User.create!(email: email, password: password, admin: admin)
  end

  describe "GET /admin" do
    it "redirects a signed-out visitor to sign in" do
      get admin_root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a signed-in non-admin away" do
      sign_in create_user(email: "customer@example.com")

      get admin_root_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end

    it "renders for an admin" do
      sign_in create_user(email: "owner@example.com", admin: true)

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pulpit")
    end

    it "renders the booking lists when there is data" do
      customer = create_user(email: "customer@example.com")
      package = create_package(name: "Konsultacja")
      Booking.create!(
        name: "Anna Kowalska",
        email: "anna@example.com",
        starts_at: 3.days.from_now,
        status: :confirmed,
        package: package,
        user: customer
      )

      sign_in create_user(email: "owner@example.com", admin: true)

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Anna Kowalska", "Konsultacja", "Opłacona")
    end
  end
end
