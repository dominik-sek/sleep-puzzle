class ApplicationController < ActionController::Base
  # provides #pagy, used as `@pagy, @records = pagy(scope)`
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_pagy_locale

  def after_sign_in_path_for(resource)
    dashboard_index_path
  end

  # The session survives sign-in, so a cart filled while signed out is still
  # there afterwards without anything having to merge it.
  def current_cart
    @current_cart ||= Cart.from_session(session)
  end
  helper_method :current_cart

  private

  # Pagy keeps its locale in a thread local, so it has to be set on every
  # request: a thread carried over from an earlier request would otherwise still
  # be holding that request's locale.
  def set_pagy_locale
    Pagy::I18n.locale = I18n.locale
  end
end
