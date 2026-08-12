import { Controller } from "@hotwired/stimulus";
import { showToast } from "./toast_controller";

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

    // the layout re-emits Paddle.js' single global callback as `paddle:event`
    #onPaddleEvent = (event) => {
        // payment is through and Paddle is about to send the buyer to successUrl —
        // tell the calendar to shut itself down until that navigation lands
        if (event.detail?.name === "checkout.completed") this.dispatch("completed", { target: window });
    };

    connect() {
        window.addEventListener("paddle:event", this.#onPaddleEvent);

        // ad blockers and privacy extensions routinely block cdn.paddle.com, which
        // used to fail silently: the booking saved, the toast said "reserved", and
        // no checkout ever appeared
        if (typeof Paddle === "undefined") {
            console.warn("[paddle] Paddle.js has not loaded yet");
            this.#reportFailure("Skrypt płatności został zablokowany. Wyłącz blokowanie reklam dla tej strony lub spróbuj w innej przeglądarce.");
            return;
        }

        try {
            Paddle.Checkout.open({
                items: [ { priceId: this.priceIdValue, quantity: this.quantityValue } ],
                customer: { id: this.customerIdValue },
                // the transaction.completed webhook reads this back to find the booking
                customData: { booking_id: String(this.bookingIdValue) },
                // Paddle closes the overlay itself and sends the buyer here on success
                settings: { successUrl: this.successUrlValue }
            });
        } catch (error) {
            console.error("[paddle] Checkout.open failed", error);
            this.#reportFailure("Spróbuj ponownie za chwilę lub wybierz inny termin.");
        }
    }

    disconnect() {
        window.removeEventListener("paddle:event", this.#onPaddleEvent);
    }

    #reportFailure(description) {
        showToast({
            title: "Nie udało się otworzyć płatności",
            description: description,
            type: "error",
            // longer than the default: this one has to actually be read
            duration: 10000
        });
    }
}
