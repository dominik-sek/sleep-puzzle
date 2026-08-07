import { Controller } from "@hotwired/stimulus";

// Toasts dispatched before the container controller connects (e.g. a flash
// partial that sits earlier in the DOM) are buffered here and drained on connect.
const pendingToasts = [];
let activeController = null;

export function showToast(options) {
    if (activeController) {
        activeController.show(options);
    } else {
        pendingToasts.push(options);
    }
}

const COLLAPSED_PEEK = 16; // px each stacked toast peeks out from under the front one
const ENTER_DURATION = 400;
const EXIT_DURATION = 250;

const TONE_CLASSES = {
    success: "text-emerald-400",
    error: "text-red-400",
    danger: "text-red-400",
    warning: "text-accent-gold",
    info: "text-accent-coral",
    loading: "text-accent",
    default: "text-tan",
};

const ICONS = {
    success: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5"><circle cx="10" cy="10" r="7.5"/><path d="m6.75 10.25 2.25 2.25 4.25-4.75"/></svg>`,
    error: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5"><circle cx="10" cy="10" r="7.5"/><path d="M7.5 7.5l5 5m0-5l-5 5"/></svg>`,
    warning: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5"><path d="M10 2.75 18 16.5H2z"/><path d="M10 7.75v3.5m0 2.5h.01"/></svg>`,
    info: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5"><circle cx="10" cy="10" r="7.5"/><path d="M10 9.25v4m0-6.5h.01"/></svg>`,
    loading: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" class="size-5 animate-spin"><circle cx="10" cy="10" r="7.5" class="opacity-30"/><path d="M17.5 10a7.5 7.5 0 0 0-7.5-7.5"/></svg>`,
    default: `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5"><circle cx="10" cy="10" r="7.5"/><path d="M10 9.25v4m0-6.5h.01"/></svg>`,
};

const CLOSE_ICON = `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" class="size-4"><path d="M6 6l8 8m0-8l-8 8"/></svg>`;

const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ESCAPES[char]);

export default class extends Controller {
    static targets = ["container"];

    static values = {
        position: { type: String, default: "top-center" },
        layout: { type: String, default: "default" },
        autoDismissDuration: { type: Number, default: 4000 },
        limit: { type: Number, default: 3 },
        gap: { type: Number, default: 14 },
    };

    connect() {
        this.toasts = [];
        this.hovering = false;

        this.containerTarget.style.transition = `height ${ENTER_DURATION}ms cubic-bezier(0.22, 1, 0.36, 1)`;

        // Toast copy wraps to a different number of lines per breakpoint, so the
        // stack has to be re-measured whenever a toast changes height.
        this.resizeObserver = new ResizeObserver(() => {
            this.toasts.forEach((toast) => this.measure(toast));
            this.layoutToasts();
        });

        this.handleWindowToast = (event) => this.show(event.detail || {});
        window.addEventListener("toast:show", this.handleWindowToast);

        activeController = this;
        pendingToasts.splice(0).forEach((options) => this.show(options));
    }

    disconnect() {
        window.removeEventListener("toast:show", this.handleWindowToast);
        this.resizeObserver.disconnect();
        this.toasts.forEach((toast) => this.pauseTimer(toast));
        this.toasts = [];
        if (activeController === this) activeController = null;
    }

    show({ title, description, type = "default", duration } = {}) {
        if (!title && !description) return;

        const toastType = TONE_CLASSES[type] ? type : "default";
        const element = this.buildElement({ title, description, type: toastType });
        const toast = {
            element,
            type: toastType,
            duration: duration ?? this.autoDismissDurationValue,
            remaining: null,
            timer: null,
            startedAt: null,
            height: 0,
            y: 0,
        };

        element.querySelector("[data-toast-close]").addEventListener("click", () => this.dismiss(toast));

        // Start off-screen, in the direction the stack enters from.
        element.style.transform = `translateY(${this.direction * -100}%) scale(0.96)`;
        element.style.opacity = "0";

        this.containerTarget.prepend(element);
        this.toasts.unshift(toast);
        this.measure(toast);
        this.resizeObserver.observe(element);

        requestAnimationFrame(() => {
            element.style.transition = `transform ${ENTER_DURATION}ms cubic-bezier(0.22, 1, 0.36, 1), opacity ${ENTER_DURATION}ms ease-out`;
            this.layoutToasts();
        });

        this.startTimer(toast);
        this.trim();
    }

    dismiss(toast) {
        if (toast.dismissing) return;
        toast.dismissing = true;

        this.pauseTimer(toast);
        this.resizeObserver.unobserve(toast.element);

        const index = this.toasts.indexOf(toast);
        if (index !== -1) this.toasts.splice(index, 1);

        toast.element.style.transition = `transform ${EXIT_DURATION}ms ease-in, opacity ${EXIT_DURATION}ms ease-in`;
        toast.element.style.transform = `translateY(${toast.y}px) scale(0.92)`;
        toast.element.style.opacity = "0";

        setTimeout(() => toast.element.remove(), EXIT_DURATION);
        this.layoutToasts();
    }

    handleMouseEnter() {
        this.hovering = true;
        this.toasts.forEach((toast) => this.pauseTimer(toast));
        this.layoutToasts();
    }

    handleMouseLeave() {
        this.hovering = false;
        this.toasts.forEach((toast) => this.startTimer(toast));
        this.layoutToasts();
    }

    // Positions every toast relative to the front one: collapsed the stack peeks
    // and scales down behind it, expanded (layout value or hover) it fans out.
    layoutToasts() {
        const expanded = this.layoutValue === "expanded" || this.hovering;
        let offset = 0;
        let height = 0;

        this.toasts.forEach((toast, index) => {
            const visible = index < this.limitValue;

            let y;
            let scale;
            if (expanded) {
                y = offset;
                scale = 1;
                offset += toast.height + this.gapValue;
                if (visible) height = offset - this.gapValue;
            } else {
                y = index * COLLAPSED_PEEK;
                scale = Math.max(0.85, 1 - index * 0.05);
                if (index === 0) height = toast.height;
            }

            toast.y = this.direction * y;
            toast.element.style.transform = `translateY(${toast.y}px) scale(${scale})`;
            toast.element.style.opacity = visible ? "1" : "0";
            toast.element.style.pointerEvents = visible ? "auto" : "none";
            toast.element.style.zIndex = String(this.toasts.length - index);
        });

        this.containerTarget.style.height = `${Math.max(height, 0)}px`;
    }

    trim() {
        this.toasts.slice(this.limitValue).forEach((toast) => this.dismiss(toast));
    }

    measure(toast) {
        toast.height = toast.element.offsetHeight;
    }

    startTimer(toast) {
        if (toast.dismissing || toast.timer || this.hovering) return;
        if (!toast.duration || toast.type === "loading") return;

        toast.startedAt = Date.now();
        toast.timer = setTimeout(() => this.dismiss(toast), toast.remaining ?? toast.duration);
    }

    pauseTimer(toast) {
        if (!toast.timer) return;

        clearTimeout(toast.timer);
        toast.timer = null;
        toast.remaining = Math.max(0, (toast.remaining ?? toast.duration) - (Date.now() - toast.startedAt));
    }

    buildElement({ title, description, type }) {
        const li = document.createElement("li");
        li.className = "absolute inset-x-0 will-change-transform";
        li.style[this.isTop ? "top" : "bottom"] = "0";
        li.style.transformOrigin = this.isTop ? "top center" : "bottom center";
        li.setAttribute("role", "status");
        li.setAttribute("aria-live", "polite");

        li.innerHTML = `
      <div class="flex items-start gap-3 rounded-xl border border-border-strong bg-surface px-4 py-3 shadow-lg shadow-black/40">
        <span class="mt-0.5 shrink-0 ${TONE_CLASSES[type]}">${ICONS[type]}</span>
        <div class="min-w-0 flex-1">
          <p class="text-t5 text-cream">${escapeHtml(title)}</p>
          ${description ? `<p class="mt-0.5 text-t6 font-normal tracking-normal text-taupe">${escapeHtml(description)}</p>` : ""}
        </div>
        <button type="button" data-toast-close class="-mr-1 shrink-0 rounded-md p-1 text-taupe transition-colors hover:text-cream" aria-label="Zamknij">
          ${CLOSE_ICON}
        </button>
      </div>
    `;

        return li;
    }

    get isTop() {
        return this.positionValue.startsWith("top");
    }

    // Toasts anchored at the bottom stack upwards, so every offset flips sign.
    get direction() {
        return this.isTop ? 1 : -1;
    }
}
