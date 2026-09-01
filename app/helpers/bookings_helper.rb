module BookingsHelper
  # Built from an actual slot time rather than once for the page: the booking
  # window runs two months, so it can straddle the DST change and the slots on
  # either side of it are on different offsets. The earliest slot of the day is
  # 08:15, long after the 03:00 changeover, so one label per date is right for
  # every slot on it.
  def booking_timezone_label(at)
    t("bookings.timezone", zone: booking_zone_name, offset: utc_offset_label(at))
  end

  private

  # Time.zone.name is the Rails identifier ("Warsaw") - English, and a stray
  # English word on the Polish page. Falls back to it so changing
  # config.time_zone leaves an unlabelled zone rather than a blank one.
  def booking_zone_name
    t("bookings.time_zones.#{Time.zone.name.parameterize(separator: '_')}", default: Time.zone.name)
  end

  def utc_offset_label(at)
    hours, minutes = (at.utc_offset / 60).abs.divmod(60)
    sign = at.utc_offset.negative? ? "-" : "+"

    minutes.zero? ? "#{sign}#{hours}" : format("%s%d:%02d", sign, hours, minutes)
  end
end
