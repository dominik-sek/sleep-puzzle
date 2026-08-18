require 'rails_helper'

# Written after several rounds of "it is translated now" that were not. Rather than
# asserting a handful of phrases are gone, this scans the rendered page for Polish
# — which catches copy nobody thought to look for, including strings coming out of
# Ruby constants rather than views.
#
# It is a net, not a proof. Diacritics alone miss plenty of Polish: "Twoje dane",
# "Pakiet" and "Status" are all pure ASCII, and the first of those sat on the
# booking page through two passes that this file called clean. Hence the word list
# underneath — still not exhaustive, so a hit is a bug but silence is only weak
# evidence.
#
# CMS copy is the deliberate exception: a block with no English version falls back
# to Polish on purpose, and that is content waiting to be written, not a bug.
RSpec.describe "English pages", type: :request do
  POLISH_ONLY = /[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]/
  # ASCII-only Polish that turns up in UI chrome. Deliberately excludes words that
  # are also English ("email", "status", "panel", "nie"), which would fire on every
  # correctly translated page.
  POLISH_WORDS = %w[twoje dane pakiet pakiety termin terminy wybierz zaloguj wyloguj
                    koszyk konto haslo imie nazwisko wyslij zapisz usun dodaj].freeze

  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  # everything outside the CMS-driven copy: the chrome, the forms, the statuses
  def polish_leftovers(body)
    body
      .gsub(%r{<script.*?</script>}m, "")
      .gsub(%r{<!--.*?-->}m, "")
      .scan(/>[^<>]*</)
      .select { |text| text.match?(POLISH_ONLY) || polish_word?(text) }
      .map { |text| text.tr("><", "").strip }
      .reject(&:empty?)
      .uniq
  end

  def polish_word?(text)
    words = text.downcase.split(/\W+/)
    POLISH_WORDS.any? { |word| words.include?(word) }
  end

  before do
    allow(GoogleCalendarService).to receive(:call)
      .and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call)
      .and_return([ paddle_price(id: "pri_456", amount: "2500", currency: "PLN") ])
  end

  describe "the booking calendar" do
    before { sign_in user }

    it "renders no missing translations" do
      get bookings_path(locale: :en)

      expect(response.body).not_to include("translation missing")
    end

    it "translates the slot picker's own copy" do
      get bookings_path(locale: :en)

      expect(response.body).to include("Available times")
      expect(response.body).to include("Pick a day in the calendar")
      expect(response.body).to include("Pay and confirm the booking")
      expect(response.body).to include("Choose a package")
    end

    it "translates the month arrows" do
      get bookings_path(locale: :en)

      expect(response.body).to include(%(aria-label="Previous month"))
      expect(response.body).not_to include(%(aria-label="Previous"))
    end

    # The controller module is evaluated once per full page load, so a locale read
    # at import survives every Turbo navigation — which is why switching language
    # used to leave the date picker in the language you arrived in until you
    # pressed reload. The server states it on the element instead, and it comes
    # with the swapped body.
    it "states the locale on the calendar element for the picker to read" do
      get bookings_path(locale: :en)

      expect(response.body).to include(%(data-cally-locale-value="en"))
    end

    it "states Polish there too, rather than leaving it to a default" do
      get bookings_path

      expect(response.body).to include(%(data-cally-locale-value="pl"))
    end

    it "leaves no Polish behind outside the CMS copy" do
      get bookings_path(locale: :en)

      expect(polish_leftovers(response.body)).to be_empty
    end
  end

  describe "the booking summary" do
    before { sign_in user }

    def booking(status)
      Booking.create!(user: user, package: create_package(name: "Quick relief"), name: "Jane",
                      email: user.email, starts_at: 3.days.from_now, status: status)
    end

    it "translates the confirmed state and its payment status" do
      get booking_path(booking(:confirmed), locale: :en)

      expect(response.body).to include("Your booking is confirmed")
      expect(response.body).to include("Payment status")
      expect(response.body).to include("Paid")
    end

    it "translates the failed state" do
      get booking_path(booking(:payment_failed), locale: :en)

      expect(response.body).to include("The payment did not go through")
    end

    it "translates the still-processing state" do
      get booking_path(booking(:pending), locale: :en)

      expect(response.body).to include("Processing the payment")
    end
  end

  # these came out of frozen Polish Hashes in the models, so they were Polish on
  # every English page however well the views were translated
  describe "labels that used to be Ruby constants" do
    it "translates a product's kind on the shop" do
      create_product(name: "The owl story", kind: :audio_process)

      get products_path(locale: :en)

      expect(response.body).to include("Audio process")
      expect(response.body).not_to include("Audioproces")
    end

    it "translates it in the cart too" do
      product = create_product(name: "The owl story", kind: :bedtime_story)
      post cart_items_path, params: { product_id: product.id }

      get cart_path(locale: :en)

      expect(response.body).to include("Bedtime story")
      expect(response.body).not_to include("Bajka na dobranoc")
    end

    it "translates a booking's status in the dashboard" do
      sign_in user
      Booking.create!(user: user, package: create_package(name: "Quick relief"), name: "Jane",
                      email: user.email, starts_at: 3.days.from_now, status: :pending)

      get dashboard_index_path(locale: :en)

      expect(response.body).to include("Awaiting payment")
      expect(response.body).not_to include("Oczekuje na płatność")
    end
  end

  # Turbo Drive swaps the body and merges the head but never touches <html>'s own
  # attributes, so lang= goes stale on navigation. locale_controller copies it back
  # up from the body, which does get replaced.
  describe "the document language" do
    it "is carried on the body, where a Turbo navigation will refresh it" do
      get about_path(locale: :en)

      expect(response.body).to include(%(data-locale-tag-value="en"))
    end

    it "matches the page in Polish too" do
      get about_path

      expect(response.body).to include(%(data-locale-tag-value="pl"))
      expect(response.body).to include(%(<html lang="pl">))
    end
  end

  # the owner's calendar is hers, in her language, whoever booked
  describe "the Google Calendar event" do
    it "stays Polish for an English buyer" do
      booking = Booking.create!(user: user, package: create_package(name: "Quick relief"),
                                name: "Jane", email: user.email,
                                starts_at: 3.days.from_now, status: :confirmed)

      summary = I18n.with_locale(:en) do
        BookingCalendarService.call(booking: booking).send(:summary)
      end

      expect(summary).to include("Opłacona")
    end
  end
end
