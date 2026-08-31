class ApplicationController < ActionController::Base
  # provides #pagy, used as `@pagy, @records = pagy(scope)`
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Declared before set_pagy_locale so the before_action runs inside it and reads
  # the locale this request actually resolved to.
  around_action :switch_locale

  before_action :set_pagy_locale
  before_action :set_sentry_user

  # Devise stores the blocked URL when `authenticate_user!` turns someone away, so
  # honour it before falling back to the dashboard. Without this a visitor who
  # picked a package on /pakiety and hit the sign-in wall landed on an empty
  # dashboard with the package_id — and the decision the page existed to capture —
  # thrown away, and no route back except finding the card again.
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_index_path
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
    locale = requested_locale

    # Remember what the public site was last showing, so the pages whose path
    # *cannot* say it follow along. The Google handshake is the case that needs
    # this: it leaves for accounts.google.com and comes back to
    # /users/auth/google_oauth2/callback with nothing to say which language the
    # visitor had picked, and the sign-in redirect it builds would land on the
    # Polish dashboard.
    session[:locale] = locale.to_s if locale_scoped_route?

    I18n.with_locale(locale, &action)
  end

  # The URL first, and on the public site the URL is the whole answer: a scoped
  # route states the language in its path, so a path without one means Polish.
  # That is what keeps one address per rendering — /about is always Polish, however
  # long ago someone clicked EN — and it is what lets the switcher get back.
  #
  # Only the routes that cannot carry a locale — Devise, the panel, the OAuth
  # callback — fall back to what was last chosen.
  def requested_locale
    known = I18n.available_locales.map(&:to_s)
    from_url = params[:locale].presence_in(known)

    return from_url if from_url
    return I18n.default_locale if locale_scoped_route?

    session[:locale].presence_in(known) || I18n.default_locale
  end

  # Whether this route can say the language in its path.
  #
  # Read off the matched route's own pattern — "(/:locale)/about(.:format)" for a
  # scoped route, "/users/sign_in(.:format)" for one outside the scope.
  #
  # Deliberately *not* done by generating a URL and looking at it: ActionController
  # memoises `url_options` on first use, so calling url_for here — before
  # with_locale has run — froze `locale: nil` into every link the page went on to
  # generate. The page came out in English with Polish links.
  def locale_scoped_route?
    return @locale_scoped_route if defined?(@locale_scoped_route)

    @locale_scoped_route = request.route_uri_pattern.to_s.include?(":locale")
  rescue StandardError
    # no matched route to ask (a 404 rendering through here, say)
    @locale_scoped_route = false
  end

  # Who was signed in when it broke. The id alone, never the email — Sentry runs
  # with send_default_pii off and putting the address back here by hand would
  # undo that. An id is enough to find the row.
  def set_sentry_user
    return unless Sentry.initialized?

    Sentry.set_user(id: current_user&.id)
  end

  # Pagy keeps its locale in a thread local, so it has to be set on every
  # request: a thread carried over from an earlier request would otherwise still
  # be holding that request's locale.
  def set_pagy_locale
    Pagy::I18n.locale = I18n.locale
  end
end
