class ApplicationController < ActionController::Base
  # provides #pagy, used as `@pagy, @records = pagy(scope)`
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Declared before set_pagy_locale so the before_action runs inside it and reads
  # the locale this request actually resolved to.
  around_action :switch_locale

  before_action :set_pagy_locale

  def after_sign_in_path_for(resource)
    dashboard_index_path
  end

  # The session survives sign-in, so a cart filled while signed out is still
  # there afterwards without anything having to merge it.
  def current_cart
    @current_cart ||= Cart.from_session(session, owner: current_user)
  end
  helper_method :current_cart

  # Carries the language from page to page without every link_to having to pass it.
  #
  # Only a non-default locale is ever put in a URL, so Polish paths stay exactly
  # what they were and each page has one canonical address. On the routes that are
  # not locale-scoped — Devise, the panel — this arrives as `?locale=en` instead,
  # which is what keeps someone who switched to English in English when they sign in.
  def default_url_options
    { locale: (I18n.locale unless I18n.locale == I18n.default_locale) }
  end

  private

  # `with_locale` rather than assigning I18n.locale: it is a thread-global, and a
  # request that set it and raised would leave the next request on this thread
  # rendering in whatever language the last one asked for.
  def switch_locale(&action)
    I18n.with_locale(requested_locale, &action)
  end

  # An unknown or missing locale is the default rather than an error: these come
  # from a URL, and a hand-edited one should show the Polish page, not a 500.
  def requested_locale
    params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end

  # Pagy keeps its locale in a thread local, so it has to be set on every
  # request: a thread carried over from an earlier request would otherwise still
  # be holding that request's locale.
  def set_pagy_locale
    Pagy::I18n.locale = I18n.locale
  end
end
