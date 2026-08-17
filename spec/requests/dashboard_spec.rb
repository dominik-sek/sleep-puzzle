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
end
