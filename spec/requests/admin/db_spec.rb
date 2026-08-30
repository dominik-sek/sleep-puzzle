require 'rails_helper'

# PgHero is a mounted engine with no base controller to inherit from, so the
# admin flag lives on the route itself. That is easy to get wrong in a way
# nothing else notices — a mount a line higher up, outside the `authenticate`
# block, would hand the query stats to anyone who guessed the path.
RSpec.describe "Admin::Db", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  describe "access" do
    it "sends a signed-out visitor to sign in" do
      get admin_pg_hero_path

      # the literal path, not new_user_session_path: the helper resolves against
      # the engine that served the request and would name /admin/db/users/sign_in
      expect(response).to redirect_to("/users/sign_in")
    end

    it "does not route for a signed-in non-admin" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      get admin_pg_hero_path

      # no matching route rather than a redirect, since the constraint is the
      # route's — which is a 404 here and in production
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/db" do
    # Runs outside the usual wrapping transaction. PgHero asks whether query
    # stats are readable by selecting from pg_stat_statements and rescuing the
    # failure, which is fine against a connection of its own and fatal inside
    # one: the failed statement aborts the enclosing transaction, and every
    # query the page makes afterwards dies with InFailedSqlTransaction. That is
    # an artefact of transactional tests on a database without the extension,
    # not something the dashboard does to a real request.
    self.use_transactional_tests = false

    before { sign_in admin }
    after { User.delete_all }

    it "renders the dashboard without asking for a second password" do
      get admin_pg_hero_path

      # 200 rather than the 401 an engine's own http_basic_auth returns when it
      # is left enabled and unconfigured
      expect(response).to have_http_status(:ok)
    end
  end
end
