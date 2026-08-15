module AdminHelper
  # Sidebar entry. `active` is passed explicitly for sections whose sub-pages
  # (edit, new, ...) should keep the parent item highlighted; it falls back to an
  # exact page match, which is what the single-page sections want.
  def admin_nav_link(label, path, icon_name, active: nil)
    active = current_page?(path) if active.nil?

    state_classes =
      if active
        "bg-ink text-cream"
      else
        "text-taupe hover:bg-ink-soft hover:text-cream"
      end

    link_to path,
            class: "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium no-underline #{state_classes}",
            aria: { current: ("page" if active) } do
      safe_join([
        icon(icon_name, class: "size-4 shrink-0"),
        tag.span(label, class: "whitespace-nowrap")
      ])
    end
  end

  # Filter pill on the bookings index. `status` nil means "all".
  def admin_booking_filter_link(label, status, current_status)
    active = status.to_s == current_status.to_s

    state_classes =
      if active
        "bg-accent text-ink border-accent-terracotta/30"
      else
        "bg-surface text-tan border-border-input hover:bg-ink-soft hover:text-cream"
      end

    link_to label,
            admin_bookings_path(status: status),
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
  # These classes only reach the stylesheet because application.css has
  # `@source "../../helpers"` — without it Tailwind never sees this file.
  def admin_booking_status_classes(booking)
    case booking.status
    when "pending" then "bg-yellow-400/15 text-yellow-300 border-yellow-400/30"
    when "confirmed" then "bg-emerald-500/15 text-emerald-300 border-emerald-500/30"
    when "payment_failed" then "bg-orange-500/15 text-orange-400 border-orange-500/30"
    when "canceled" then "bg-red-500/15 text-red-400 border-red-500/30"
    else "bg-taupe/10 text-taupe border-taupe/20"
    end
  end
end
