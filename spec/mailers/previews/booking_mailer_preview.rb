# Preview booking mail at http://localhost:3000/rails/mailers/booking_mailer
#
# Uses an unsaved booking so previewing never touches real data.
class BookingMailerPreview < ActionMailer::Preview
  def confirmed
    BookingMailer.with(booking: example_booking(:confirmed)).confirmed
  end

  def new_booking
    BookingMailer.with(booking: example_booking(:confirmed)).new_booking
  end

  def payment_failed
    BookingMailer.with(booking: example_booking(:payment_failed)).payment_failed
  end

  private

  def example_booking(status)
    Booking.new(
      id: 0,
      token: "podglad0000000000000000",
      name: "Jan Kowalski",
      email: "jan@example.com",
      starts_at: 3.days.from_now.change(hour: 8, min: 15),
      status: status,
      package: Package.first || preview_package
    )
  end

  # Package copy lives in a jsonb store, so an unsaved stand-in has to be given
  # its name the same way the admin panel would.
  def preview_package
    Package.new.tap { |package| package.assign_translation(:name, :pl, "Szybka ulga") }
  end
end
