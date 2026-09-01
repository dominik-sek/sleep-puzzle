require 'rails_helper'

# The dashboard is a mounted engine, so the thing worth pinning is that it is
# actually behind the admin flag - an engine mounted a line higher up, outside
# the namespace, would serve the queue to anyone.
RSpec.describe "Admin::Jobs", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  describe "access" do
    it "redirects a signed-out visitor to sign in" do
      get admin_mission_control_jobs_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects a signed-in non-admin away" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      get admin_mission_control_jobs_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/jobs" do
    before { sign_in admin }

    it "renders the dashboard without asking for a second password" do
      get admin_mission_control_jobs_path

      # 200 rather than the 401 the engine's own http_basic_auth returns when
      # it is left enabled and unconfigured, which is its default
      expect(response).to have_http_status(:ok)
    end
  end
end
