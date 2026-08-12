import { Controller } from "@hotwired/stimulus";

// Opens Paddle checkout for a booking that bookings#create has just saved as
// pending. Rendered only by the create response, so connect() fires once per
// booking rather than on every page load.
export default class extends Controller {
    static values = {
        priceId: String,
        customerId: String,
        bookingId: Number,
        successUrl: String,
        quantity: { type: Number, default: 1 }
    };

    connect() {
        if (typeof Paddle === "undefined") {
            console.warn("[paddle] Paddle.js has not loaded yet");
            return;
        }

        Paddle.Checkout.open({
            items: [ { priceId: this.priceIdValue, quantity: this.quantityValue } ],
            customer: { id: this.customerIdValue },
            // the transaction.completed webhook reads this back to find the booking
            customData: { booking_id: String(this.bookingIdValue) },
            // Paddle closes the overlay itself and sends the buyer here on success
            settings: { successUrl: this.successUrlValue }
        });
    }
}
