import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";
import { showToast } from "./toast_controller";
import { loadPaddle } from "../lib/paddle";

// Opens Paddle checkout for something the server has just saved as pending - a
// booking holding a slot, or an order holding a cart. Rendered only by the
// create response, so connect() fires once per checkout rather than on every
// page load.
//
// Everything specific to *what* is being bought arrives as values: `items` is
// what Paddle charges for, `customData` is what the transaction webhook reads
// back to find the record. The controller itself knows neither.
//
// The toast copy arrives as values too. Stimulus controllers have no `t()`, and
// this one is buyer-facing on both the Polish and the English site, so the
// strings are resolved by the partial that mounts it rather than living here.
//
// Paddle.js itself is fetched here rather than by the layout, so a visitor who
// never buys anything never gets Paddle's cookies - see lib/paddle.js.
export default class extends Controller {
    static values = {
        token: String,
        environment: String,
        items: Array,
        customData: Object,
        customerId: String,
        successUrl: String,
        abandonUrl: String,
        openFailedTitle: String,
        blockedMessage: String,
        retryMessage: String,
        errorTitle: String,
        errorFallback: String
    };

    // Paddle closes the overlay itself after a completed payment, so `checkout.closed`
    // alone can't tell "the buyer gave up" from "the payment went through"
    #completed = false;

    // fetching Paddle.js is a round trip, so the element can go away before the
    // overlay would have opened
    #disconnected = false;

    // loadPaddle re-emits Paddle.js' single global callback as `paddle:event`
    #onPaddleEvent = (event) => {
        switch (event.detail?.name) {
            case "checkout.completed":
                // payment is through and Paddle is about to send the buyer to successUrl -
                // tell the calendar to shut itself down until that navigation lands
                this.#completed = true;
                this.dispatch("completed", { target: window });
                break;
            case "checkout.closed":
                if (!this.#completed) this.#abandon();
                break;
            // A declined card, an expired transaction, a network failure inside the
            // overlay. Paddle shows its own message in the overlay, but only while the
            // overlay is up - nothing reached us before, which is why the max-quantity
            // rejection had to be diagnosed by hand.
            //
            // Deliberately does *not* abandon: the overlay stays open and the buyer can
            // retry in it. If they give up instead, `checkout.closed` follows and
            // releases the record.
            case "checkout.error":
                console.error("[paddle] checkout error", event.detail);
                showToast({
                    title: this.errorTitleValue,
                    description: this.#errorDescription(event.detail),
                    type: "error",
                    duration: 10000
                });
                break;
        }
    };

    // Paddle has moved this field around between versions and does not document a
    // stable shape for it, so every plausible spot is tried before falling back to
    // our own copy - a wrong-looking message is still better than none.
    #errorDescription(detail) {
        const error = detail?.error ?? detail?.data?.error;
        const message = typeof error === "string" ? error : error?.detail ?? error?.message;

        return message || this.errorFallbackValue;
    }

    connect() {
        this.#disconnected = false;
        window.addEventListener("paddle:event", this.#onPaddleEvent);
        this.#open();
    }

    disconnect() {
        this.#disconnected = true;
        window.removeEventListener("paddle:event", this.#onPaddleEvent);
    }

    // Not awaited by connect(): Stimulus ignores the promise either way, and
    // everything after the fetch has to re-check that the element is still here.
    async #open() {
        let paddle;

        try {
            paddle = await loadPaddle({
                token: this.tokenValue,
                environment: this.environmentValue
            });
        } catch (error) {
            // ad blockers and privacy extensions routinely block cdn.paddle.com,
            // which used to fail silently: the booking saved, the toast said
            // "reserved", and no checkout ever appeared
            console.warn("[paddle] Paddle.js did not load", error);
            this.#reportFailure(this.blockedMessageValue);
            // no overlay means no `checkout.closed` either, so nothing else would
            // ever release what the pending record is holding
            this.#abandon();
            return;
        }

        // the buyer navigated away while the script was in flight - deliberately
        // not abandoned here, because Turbo also disconnects on the way into its
        // page cache and the record would still be wanted on the way back.
        // ReleaseAbandonedBookingsJob is the backstop if they really are gone.
        if (this.#disconnected) return;

        try {
            paddle.Checkout.open({
                items: this.itemsValue,
                customer: { id: this.customerIdValue },
                customData: this.customDataValue,
                // Paddle closes the overlay itself and sends the buyer here on success
                settings: { successUrl: this.successUrlValue }
            });
        } catch (error) {
            console.error("[paddle] Checkout.open failed", error);
            this.#reportFailure(this.retryMessageValue);
            this.#abandon();
        }
    }

    // The record is already saved by the time the overlay opens - a booking holding
    // its slot, an order holding the emptied cart - and walking away from it produces
    // no webhook at all, so nothing else would tell the server it never sold.
    async #abandon() {
        if (!this.hasAbandonUrlValue) return;

        try {
            const response = await fetch(this.abandonUrlValue, {
                method: "DELETE",
                headers: {
                    Accept: "text/vnd.turbo-stream.html",
                    "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
                }
            });
            if (!response.ok) throw new Error(`responded ${response.status}`);

            // puts the freed slot back on the calendar, or the lines back in the
            // cart, without a reload
            Turbo.renderStreamMessage(await response.text());
        } catch (error) {
            // not worth bothering the buyer about: ReleaseAbandonedBookingsJob still
            // frees the slot, they just won't see it come back on this page
            console.error("[paddle] clearing the abandoned checkout failed", error);
        }
    }

    #reportFailure(description) {
        showToast({
            title: this.openFailedTitleValue,
            description: description,
            type: "error",
            // longer than the default: this one has to actually be read
            duration: 10000
        });
    }
}
