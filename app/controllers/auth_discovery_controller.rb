# Public discovery must also work for agents outside the app's modern-browser gate.
class AuthDiscoveryController < ActionController::Base
  def show
    render plain: Rails.root.join("docs/auth.md").read, content_type: "text/markdown"
  end
end
