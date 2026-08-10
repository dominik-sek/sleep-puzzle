import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["package", "email"];
    static values = {
        quantity: { type: Number, default: 1 }
    };

    open(event) {
        event.preventDefault();

        if (typeof Paddle === "undefined") {
            console.warn("[paddle] Paddle.js has not loaded yet");
            return;
        }

        const priceId = this.packageTarget.selectedOptions[0]?.dataset.priceId;
        if (!priceId) {
            console.warn("[paddle] no package selected, or it has no Paddle price");
            return;
        }

        const email = this.emailTarget.value;

        Paddle.Checkout.open({
            items: [ { priceId: priceId, quantity: this.quantityValue } ],
            customer: email ? { email: email } : undefined
        });
    }
}
