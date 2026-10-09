require "rails_helper"

RSpec.describe "Admin refund instructions", type: :request do
  it "requires signing in" do
    get admin_refunds_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "requires admin access" do
    sign_in User.create!(email: "refund-buyer@example.com", password: "password123")
    get admin_refunds_path
    expect(response).to redirect_to(root_path)
  end

  it "shows the manual workflow with separate booking and payment steps" do
    sign_in User.create!(email: "refund-admin@example.com", password: "password123", admin: true)
    get admin_refunds_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jak obsłużyć zwrot", "Request refund", "adjustment.updated", "Brak zarejestrowanego odtworzenia")
  end
end
