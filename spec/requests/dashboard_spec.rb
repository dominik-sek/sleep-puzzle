require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }
  let(:product) { create_product(name: "Bajka o sowie") }

  def paid_order_for(*products, user: self.user)
    order = user.orders.create!(
      status: :pending,
      order_items: products.map { |p| OrderItem.new(product: p) }
    )
    order.mark_paid!(transaction_id: "txn_#{order.id}")
    order
  end

  def booking_for(starts_at:, status: :confirmed, user: self.user)
    Booking.create!(user: user, package: create_package(name: "Szybka ulga"), name: "Ala",
                    email: user.email, starts_at: starts_at, status: status)
  end

  it "sends a signed-out visitor to sign in" do
    get dashboard_index_path

    expect(response).to redirect_to(new_user_session_path)
  end

  describe "when signed in" do
    before { sign_in user }

    it "renders the CMS copy and the account's email" do
      get dashboard_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Moje konto")
      expect(response.body).to include("Moje audio")
      expect(response.body).to include("Moje konsultacje")
      expect(response.body).to include("Ustawienia")
      expect(response.body).to include("customer@example.com")
    end

    describe "the audio library" do
      it "lists what the buyer has paid for" do
        paid_order_for(product)

        get dashboard_index_path

        expect(response.body).to include("Bajka o sowie")
        expect(response.body).to include(product.kind_label)
      end

      # an order Paddle has not confirmed is not a purchase
      it "does not list an unpaid order's products" do
        user.orders.create!(status: :pending, order_items: [ OrderItem.new(product: product) ])

        get dashboard_index_path

        expect(response.body).not_to include("Bajka o sowie")
        expect(response.body).to include("Nie masz jeszcze żadnych audio")
      end

      it "lists a product bought in two orders only once" do
        paid_order_for(product)
        paid_order_for(product)

        get dashboard_index_path

        expect(response.body.scan(%(href="#{product_path(product)}")).size).to eq(1)
      end

      it "does not leak another buyer's library" do
        paid_order_for(product, user: User.create!(email: "other@example.com", password: "password123"))

        get dashboard_index_path

        expect(response.body).not_to include("Bajka o sowie")
      end

      describe "the player" do
        let(:product) { create_product(name: "Bajka o sowie", cdn_path: "/bajki/o-sowie.mp3") }

        it "gives a bought recording a player pointed at the gated stream" do
          with_bunny_cdn
          paid_order_for(product)

          get dashboard_index_path

          expect(response.body).to include(%(src="#{stream_product_path(product)}"))
        end

        # nothing is fetched from the CDN, and no token is minted, until the buyer
        # actually presses play
        it "does not preload the audio" do
          with_bunny_cdn
          paid_order_for(product)

          get dashboard_index_path

          expect(response.body).to include(%(preload="none"))
        end

        # a control with nothing behind it would be a lie — the same reason the
        # library had no player at all before the CDN existed
        it "leaves out the player when no file has been uploaded" do
          with_bunny_cdn
          paid_order_for(create_product(name: "Bez pliku", published: false, cdn_path: nil))

          get dashboard_index_path

          expect(response.body).to include("Bez pliku")
          expect(response.body).not_to include("<audio")
        end

        it "leaves out the player when the CDN is unconfigured" do
          paid_order_for(product)

          get dashboard_index_path

          expect(response.body).to include("Bajka o sowie")
          expect(response.body).not_to include("<audio")
        end
      end

      # an empty section that only says "nothing here" leaves the buyer to go and
      # find the shop themselves
      it "points an empty library at the shop" do
        get dashboard_index_path

        expect(response.body).to include("Nie masz jeszcze żadnych audio")
        expect(response.body).to include(%(href="#{products_path}"))
      end
    end

    describe "the consultations" do
      it "shows an upcoming booking with its package" do
        booking_for(starts_at: 3.days.from_now)

        get dashboard_index_path

        expect(response.body).to include("Szybka ulga")
      end

      it "does not show one that has already happened" do
        booking_for(starts_at: 3.days.ago)

        get dashboard_index_path

        expect(response.body).to include("Nie masz zaplanowanej konsultacji")
      end

      it "does not show a canceled one" do
        booking_for(starts_at: 3.days.from_now, status: :canceled)

        get dashboard_index_path

        expect(response.body).to include("Nie masz zaplanowanej konsultacji")
      end

      # the slot is being held, so hiding it would leave the buyer wondering
      # whether the booking registered at all — but it must not read as settled
      it "shows a pending one, labelled" do
        booking_for(starts_at: 3.days.from_now, status: :pending)

        get dashboard_index_path

        expect(response.body).to include("Szybka ulga")
        expect(response.body).to include(Booking.status_label("pending"))
      end

      it "does not label a confirmed one" do
        booking_for(starts_at: 3.days.from_now)

        get dashboard_index_path

        expect(response.body).not_to include(Booking.status_label("pending"))
      end

      it "does not leak another buyer's bookings" do
        booking_for(starts_at: 3.days.from_now,
                    user: User.create!(email: "other@example.com", password: "password123"))

        get dashboard_index_path

        expect(response.body).to include("Nie masz zaplanowanej konsultacji")
      end

      it "points an empty section at the calendar" do
        get dashboard_index_path

        expect(response.body).to include(%(href="#{bookings_path}"))
      end
    end

    it "points settings at the Devise form rather than growing a second one" do
      get dashboard_index_path

      expect(response.body).to include(%(href="#{edit_user_registration_path}"))
    end

    it "offers a way out" do
      get dashboard_index_path

      expect(response.body).to include(destroy_user_session_path)
    end
  end

  # The four behaviours added after the dashboard critique. The spec file was
  # strong on what the page lists and silent on what it says, which is how the
  # Google-user copy and the unplayable state went unnoticed.
  describe "after the critique" do
    before { sign_in user }

    it "explains a purchased recording it cannot play, and offers a way to ask" do
      product = create_product(name: "Bajka", cdn_path: nil, published: false)
      paid_order_for(product)

      get dashboard_index_path

      expect(response.body).not_to include("<audio")
      expect(response.body).to include("Tego nagrania chwilowo nie da się odtworzyć")
      expect(response.body).to include(contact_path)
    end

    it "anchors each library row so the shop can link straight to one" do
      product = create_product(name: "Bajka")
      paid_order_for(product)

      get dashboard_index_path

      expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(product)}"))
      expect(response.body).to include("library-row")
    end

    it "offers to change a password when the account has one" do
      get dashboard_index_path

      expect(response.body).to include("Zmień adres e-mail, hasło i dane konta")
    end

    # a Google sign-up has never had one, and the Devise screen it links to
    # offers to *set* a password rather than change it
    it "offers to set one when the account has none" do
      user.update_columns(encrypted_password: "")

      get dashboard_index_path

      expect(response.body).to include("Możesz też ustawić hasło")
      expect(response.body).not_to include("Zmień adres e-mail, hasło i dane konta")
    end

    it "gives the empty library a real call to action rather than a bare sentence" do
      get dashboard_index_path

      expect(response.body).to include("Nie masz jeszcze żadnych audio")
      expect(response.body).to include(products_path)
    end
  end
end
