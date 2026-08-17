module NavigationHelper
  # The public site's primary navigation, in order.
  #
  # Kept here rather than in shared/_navbar because the partial renders this list
  # twice — once inline for the bar, once inside the hamburger panel — and two
  # hand-written copies drift the first time a link is added.
  #
  # Blog is designed but parked, so its entry stays commented out alongside the
  # markup that would render it.
  def primary_nav_items
    [
      { label: t("nav.packages"), href: packages_path },
      { label: t("nav.about"), href: about_path },
      # { label: t("nav.blog"), href: blog_path },
      { label: t("nav.shop"), href: products_path },
      { label: t("nav.contact"), href: contact_path }
    ]
  end

  # Flags stand for countries rather than languages, which is a compromise — but a
  # recognisable one at a glance, and the language's own name sits next to it in the
  # menu for anyone the flag does not help. British rather than American, since the
  # audience is in the EU.
  LOCALE_FLAGS = { pl: "🇵🇱", en: "🇬🇧" }.freeze

  # Each language named in itself, so "English" is legible to someone who cannot
  # read the Polish page they are currently on, and vice versa.
  LOCALE_NAMES = { pl: "Polski", en: "English" }.freeze

  def locale_flag(locale)
    LOCALE_FLAGS.fetch(locale.to_sym, "🏳️")
  end

  def locale_name(locale)
    LOCALE_NAMES.fetch(locale.to_sym, locale.to_s.upcase)
  end

  # The other language, for anything that needs the single alternative rather than
  # the whole list.
  def alternate_locale
    (I18n.available_locales - [ I18n.locale ]).first
  end

  # The current page in the other language.
  #
  # Built from the current route's own parameters rather than by rewriting the
  # path, so /products/12 switches to /en/products/12 rather than dropping the
  # buyer back on the shop index. `only_path` keeps it relative; the query string
  # is carried so a status filter or a page number survives the switch.
  def alternate_locale_url(locale = alternate_locale)
    url_for(request.query_parameters.merge(locale: locale == I18n.default_locale ? nil : locale,
                                           only_path: true))
  rescue ActionController::UrlGenerationError
    # a route that cannot be expressed in the other language — nothing on the
    # public site today, but a dead toggle beats a 500
    root_path(locale: locale == I18n.default_locale ? nil : locale)
  end

  # One row in the profile dropdown. Shared by the links and the sign-out button so
  # the two cannot drift — a hand-styled anchor next to a form-wrapped button was
  # what made the menu look uneven.
  #
  # w-full + text-left matter because `button_to` renders its button inside a form:
  # without them that row shrinks to its label while its neighbours fill the panel.
  def profile_menu_item_classes
    "flex w-full items-center gap-2.5 rounded-md px-3 py-2.5 text-left text-sm font-semibold " \
      "text-cream no-underline cursor-pointer bg-transparent border-0 hover:bg-ink-soft hover:text-accent"
  end

  # The same row, sized for the hamburger panel, where the type is a step larger.
  def mobile_menu_item_classes
    "flex w-full items-center gap-3 rounded-md px-3 py-2.5 text-left text-md font-bold " \
      "text-cream no-underline cursor-pointer bg-transparent border-0 hover:bg-ink-soft hover:text-accent"
  end
end
