import { Controller } from "@hotwired/stimulus";

// Native dialog provides a focus trap, inert background and Escape support.
// Hash links still allow sharing a package's details directly.
export default class extends Controller {
    connect() {
        this.onHashChange = () => this.openHash();
        this.onBeforeCache = () => this.close();
        window.addEventListener("hashchange", this.onHashChange);
        window.addEventListener("pageshow", this.onHashChange);
        document.addEventListener("turbo:before-cache", this.onBeforeCache);
        this.openHash();
    }

    disconnect() {
        window.removeEventListener("hashchange", this.onHashChange);
        window.removeEventListener("pageshow", this.onHashChange);
        document.removeEventListener("turbo:before-cache", this.onBeforeCache);
        this.close();
        document.documentElement.classList.remove("package-details-modal-open");
    }

    reveal(event) {
        const dialog = document.getElementById(event.currentTarget.getAttribute("aria-controls"));
        if (!this.ownsDialog(dialog)) return;
        this.opener = event.currentTarget;
        this.previousHash = window.location.hash;
        window.history.pushState(window.history.state, "", `#${dialog.id}`);
        this.show(dialog);
    }

    ownsDialog(dialog) {
        return dialog?.tagName === "DIALOG" && this.element.contains(dialog);
    }

    openHash() {
        const dialog = document.getElementById(window.location.hash.slice(1));
        if (!this.ownsDialog(dialog)) {
            this.close();
            return;
        }
        if (dialog.open) return;
        this.opener = this.element.querySelector(`button[aria-controls="${dialog.id}"]`);
        this.previousHash = "";
        this.show(dialog);
    }

    show(dialog) {
        const previousDialog = this.activeDialog;
        this.activeDialog = dialog;
        if (previousDialog?.open && previousDialog !== dialog) previousDialog.close();
        dialog.showModal();
        dialog.querySelector(".package-details-scroll").scrollTop = 0;
        document.documentElement.classList.add("package-details-modal-open");
        dialog.querySelector("[data-dialog-heading]").focus({ preventScroll: true });
    }

    backdrop(event) {
        if (event.target !== this.activeDialog) return;
        const box = this.activeDialog.getBoundingClientRect();
        if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this.close();
    }

    cancel(event) {
        event.preventDefault();
        this.close();
    }

    follow(event) {
        const link = event.target.closest("a[href]");
        if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        const destination = new URL(link.href);
        const target = document.getElementById(destination.hash.slice(1));
        const samePage = destination.origin === window.location.origin && destination.pathname === window.location.pathname && destination.search === window.location.search;
        if (samePage && target) {
            // Closing restores the card's focus and URL before moving to the
            // calendar; handling this anchor here avoids a race with Turbo.
            event.preventDefault();
            this.close();
            window.history.pushState(window.history.state, "", destination.hash);
            target.focus({ preventScroll: true });
            target.scrollIntoView({ block: "start", behavior: "instant" });
        } else {
            this.close();
        }
    }

    focusHeading(event) {
        // Browsers focus a fragment's dialog after page load. Redirect that
        // focus to its readable heading, while leaving controls untouched.
        if (event.target === this.activeDialog) {
            this.activeDialog.querySelector("[data-dialog-heading]").focus({ preventScroll: true });
        }
    }

    trapFocus(event) {
        if (event.key !== "Tab" || !this.activeDialog?.open) return;
        const controls = [...this.activeDialog.querySelectorAll("button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex='0']")]
            .filter(control => control.getClientRects().length > 0);
        const first = controls[0];
        const last = controls[controls.length - 1];
        if (event.shiftKey && (document.activeElement === first || !controls.includes(document.activeElement))) {
            event.preventDefault();
            last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first?.focus();
        }
    }

    close() {
        const dialog = this.activeDialog;
        if (!dialog) return;
        if (dialog.open) dialog.close();
        this.finishClose(dialog);
    }

    closed(event) {
        this.finishClose(event.currentTarget);
    }

    finishClose(dialog) {
        if (dialog !== this.activeDialog) return;
        document.documentElement.classList.remove("package-details-modal-open");
        if (window.location.hash === `#${this.activeDialog.id}`) {
            window.history.replaceState(window.history.state, "", `${window.location.pathname}${window.location.search}${this.previousHash || ""}`);
        }
        this.activeDialog = null;
        if (this.opener?.isConnected) this.opener.focus({ preventScroll: true });
    }
}
