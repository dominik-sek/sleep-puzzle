# frozen_string_literal: true

module Admin
  # Every admin screen inherits from this. There are only ever a couple of
  # admins, so access is a boolean on users rather than a role system.
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: "Nie masz dostępu do tej strony."
    end
  end
end
