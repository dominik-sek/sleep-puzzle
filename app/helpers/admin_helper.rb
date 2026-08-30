module AdminHelper
  # The panel's navigation, in order. Kept here rather than in the layout so the
  # active rules live next to each other and can be asserted in one place.
  def admin_sidebar_items
    [
      { label: "Pulpit", href: admin_root_path, icon: "layout-dashboard",
        active: controller_name == "dashboard" },
      { label: "Rezerwacje", href: admin_bookings_path, icon: "calendar-days",
        active: controller_name == "bookings" },
      { label: "Zamówienia", href: admin_orders_path, icon: "credit-card",
        active: controller_name == "orders" },
      { label: "Pakiety", href: admin_packages_path, icon: "package",
        active: controller_name == "packages" },
      { label: "Produkty", href: admin_products_path, icon: "audio-lines",
        active: controller_name == "products" },
      { label: "Treści", href: admin_content_blocks_path, icon: "file-text",
        active: controller_name.in?(%w[content_blocks content_items]) },
      { label: "Kalendarz", href: integrations_google_calendar_path, icon: "calendar-cog",
        active: controller_name == "google_calendar" },
      { label: "Zadania", href: admin_mission_control_jobs_path, icon: "list-checks",
        active: false },
      { label: "Baza danych", href: admin_pg_hero_path, icon: "database",
        active: false }
    ]
  end

  # Filter pill on an index that filters by status. `status` nil means "all", and
  # the caller supplies the path so bookings and orders share one pill.
  def admin_filter_link(label, status, current_status, path)
    active = status.to_s == current_status.to_s

    state_classes =
      if active
        "bg-accent text-ink border-accent-terracotta/30"
      else
        "bg-surface text-tan border-border-input hover:bg-ink-soft hover:text-cream"
      end

    link_to label, path,
            class: "inline-block rounded-full border px-3 py-1.5 text-t6 font-medium no-underline #{state_classes}"
  end

  # Rebuilds the link Google puts in an event's htmlLink, since only the raw
  # event id is stored on the booking. The `eid` param is base64 of
  # "<event id> <calendar id>" with the padding stripped, and Google abbreviates
  # the calendar id's domain down to its first character. Encoding the full
  # domain instead produces a different eid than Google's own link, so this
  # mirrors Google byte for byte (checked against the API's htmlLink).
  #
  # Returns nil when there is nothing to link to, so the caller can fall back to
  # plain text rather than render a dead link.
  def google_calendar_event_url(booking)
    calendar_id = ENV["GOOGLE_CALENDAR_ID"]
    return if booking.calendar_event_id.blank? || calendar_id.blank?

    short_calendar_id = calendar_id.sub(/@(.).*\z/, '@\1')
    eid = Base64.urlsafe_encode64("#{booking.calendar_event_id} #{short_calendar_id}", padding: false)

    "https://www.google.com/calendar/event?eid=#{eid}"
  end

  # One hue per payment state so the statuses stay tellable apart at a glance.
  # Shared by bookings and orders, which run through the same Paddle states under
  # two names — a booking ends up "confirmed", an order "paid".
  #
  # These classes only reach the stylesheet because application.css has
  # `@source "../../helpers"` — without it Tailwind never sees this file.
  def admin_status_classes(status)
    case status.to_s
    when "pending" then "bg-yellow-400/15 text-yellow-300 border-yellow-400/30"
    when "confirmed", "paid" then "bg-emerald-500/15 text-emerald-300 border-emerald-500/30"
    when "payment_failed" then "bg-orange-500/15 text-orange-400 border-orange-500/30"
    when "canceled" then "bg-red-500/15 text-red-400 border-red-500/30"
    else "bg-taupe/10 text-taupe border-taupe/20"
    end
  end

  # The pill itself, so an index and a show cannot drift on padding or shape.
  def admin_status_badge(status, label, classes: nil)
    tag.span(label,
             class: class_names("inline-block rounded-full border px-2.5 py-1 whitespace-nowrap",
                                admin_status_classes(status), classes))
  end

  # Which languages a record has actually been written in. The site falls back to
  # Polish, so a missing English version is not an error — but it is the one thing
  # about a catalogue row that is invisible until someone switches language.
  def admin_translation_badges(record, field = :name)
    safe_join(Translatable::LOCALES.map { |locale|
      filled = record.translated?(field, locale)
      state = filled ? "bg-emerald-500/15 text-emerald-300 border-emerald-500/30" : "bg-taupe/10 text-taupe border-taupe/20"

      tag.span(locale.to_s.upcase,
               class: "inline-block rounded border px-1.5 py-0.5 text-t6 font-medium #{state}",
               title: filled ? nil : "Brak tłumaczenia")
    }, " ")
  end

  # The price as Paddle reports it. `prices` is the catalogue the controller
  # already fetched, so a page of rows costs no extra API calls.
  def admin_paddle_price_cell(record, prices)
    price = prices.find { |candidate| candidate.id == record.paddle_price_id }
    return tag.span(price.formatted_amount || price.label, class: "tabular-nums whitespace-nowrap") if price

    tag.span("Nieznana cena w Paddle", class: "text-orange-400", title: record.paddle_price_id)
  end

  # A recording on its way to Bunny, or one that never got there — neither shows
  # up anywhere else on the row. Same two hues as a pending or failed payment.
  def admin_audio_upload_badge(product)
    if product.audio_upload_pending?
      admin_status_badge(:pending, "Wgrywanie…", classes: "text-t6")
    elsif product.audio_upload_failed?
      admin_status_badge(:payment_failed, "Błąd pliku", classes: "text-t6")
    end
  end

  def admin_published_badge(record)
    if record.published?
      tag.span("Widoczny", class: "inline-block rounded-full border border-emerald-500/30 bg-emerald-500/15 px-2.5 py-1 text-emerald-300 whitespace-nowrap")
    else
      tag.span("Ukryty", class: "inline-block rounded-full border border-taupe/20 bg-taupe/10 px-2.5 py-1 text-taupe whitespace-nowrap")
    end
  end
end
