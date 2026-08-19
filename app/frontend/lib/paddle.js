// Fetches Paddle.js, once, at the moment a checkout actually opens.
//
// It used to sit in the application layout, so every visitor got Paddle's
// cookies on the homepage before doing anything that resembled a purchase.
// Nothing Paddle stores is exempt from consent, which left a choice between a
// cookie banner and not loading it until it is needed; this is the second
// option. By the time this runs the buyer has a pending record and has asked
// for the overlay, which is what makes the storage strictly necessary.
//
// Memoised on the promise rather than on a boolean, so a second checkout in the
// same visit waits on the first fetch instead of racing it.

const SRC = "https://cdn.paddle.com/paddle/v2/paddle.js";

// Ad blockers and privacy extensions routinely block cdn.paddle.com. Most do it
// at the network level, which fires `error`; some answer with an empty 200
// instead, which fires `load` with no global to show for it. Neither may be left
// to hang the caller, hence the timeout as a third way out.
const TIMEOUT = 10000;

let loading = null;

export function loadPaddle({ token, environment }) {
    loading ||= new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.src = SRC;
        script.async = true;

        const fail = (reason) => {
            clearTimeout(timer);
            // a script that arrives after we have given up must not initialise
            // itself behind the caller's back
            script.remove();
            // clear the memo so a later checkout starts a fresh attempt rather
            // than being handed this rejection
            loading = null;
            reject(new Error(reason));
        };

        const timer = setTimeout(() => fail("Paddle.js did not load in time"), TIMEOUT);

        script.addEventListener("load", () => {
            if (typeof Paddle === "undefined") {
                fail("Paddle.js loaded without defining Paddle");
                return;
            }

            clearTimeout(timer);

            // has to precede Initialize, or the token is checked against the
            // wrong environment
            if (environment) Paddle.Environment.set(environment);

            Paddle.Initialize({
                token,
                // Paddle.js only takes one global callback, so it is re-emitted as
                // a DOM event and paddle_controller decides what to do with it
                eventCallback: (event) => {
                    window.dispatchEvent(new CustomEvent("paddle:event", { detail: event }));
                }
            });

            resolve(Paddle);
        });

        script.addEventListener("error", () => fail("Paddle.js could not be fetched"));

        document.head.appendChild(script);
    });

    return loading;
}
