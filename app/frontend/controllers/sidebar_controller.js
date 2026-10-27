import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sidebar"
export default class extends Controller {
    static targets = [
        "desktopSidebar",
        "mobileSidebar",
        "contentTemplate",
        "sharedContent",
        "desktopContent",
        "mobileBackdrop",
        "mobilePanel",
        "mobileToggle",
    ];
    static values = {
        storageKey: { type: String, default: "sidebarOpen" },
    };

    connect() {
        // Bind the handler once so we can properly remove it later
        this.boundHandleToggle = this.handleToggle.bind(this);
        this.desktopMedia = window.matchMedia("(min-width: 768px)");
        this.onBreakpoint = () => {
            if (this.desktopMedia.matches) this.closeMobile(false);
        };
        this.beforeCache = () => this.closeMobile(false);
        this.desktopMedia.addEventListener("change", this.onBreakpoint);
        document.addEventListener("turbo:before-cache", this.beforeCache);

        // Clone the sidebar content for both mobile and desktop
        if (this.hasContentTemplateTarget) {
            // Clone content for desktop (only if not already cloned)
            // Check if nav element exists (the actual cloned content)
            if (this.hasDesktopContentTarget && !this.desktopContentTarget.querySelector("nav")) {
                const desktopClone = this.contentTemplateTarget.content.cloneNode(true);
                this.desktopContentTarget.appendChild(desktopClone);
            }

            // Clone content for mobile (only if not already cloned)
            if (this.hasSharedContentTarget && !this.sharedContentTarget.querySelector("nav")) {
                const mobileClone = this.contentTemplateTarget.content.cloneNode(true);
                this.sharedContentTarget.appendChild(mobileClone);

                // Update the close button in mobile view to show X icon and have mobile close action
                const mobileNav = this.sharedContentTarget.querySelector("nav");
                if (mobileNav) {
                    const closeButton = mobileNav.querySelector('[data-action*="sidebar#close"]');
                    if (closeButton) {
                        closeButton.setAttribute("data-action", "click->sidebar#closeMobile");
                        closeButton.classList.remove("cursor-w-resize");
                        closeButton.setAttribute("aria-label", "Zamknij nawigację");
                        closeButton.removeAttribute("aria-expanded");
                        closeButton.setAttribute("autofocus", "");

                        // Replace the collapse icon with an X icon
                        const svg = closeButton.querySelector("svg");
                        if (svg) {
                            svg.innerHTML =
                                '<g fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" stroke="currentColor"><line x1="13.25" y1="4.75" x2="4.75" y2="13.25"></line><line x1="13.25" y1="13.25" x2="4.75" y2="4.75"></line></g>';
                        }
                    }
                }
            }
        }

        if (this.hasDesktopSidebarTarget) {
            // Temporarily disable transitions to prevent animation on page load
            this.desktopSidebarTarget.style.transition = "none";

            // Restore the saved state from localStorage, default to open if no saved state
            const savedState = localStorage.getItem(this.storageKeyValue);

            if (savedState !== null) {
                this.desktopSidebarTarget.open = savedState === "true";
            } else {
                // Default to open for first-time visitors
                this.desktopSidebarTarget.open = true;
            }

            // Re-enable transitions after a brief delay
            requestAnimationFrame(() => {
                requestAnimationFrame(() => {
                    this.desktopSidebarTarget.style.transition = "";
                });
            });

            // Listen for toggle events to save the state
            this.desktopSidebarTarget.addEventListener("toggle", this.boundHandleToggle);
        }
    }

    disconnect() {
        this.closeMobile(false);
        this.desktopMedia?.removeEventListener("change", this.onBreakpoint);
        document.removeEventListener("turbo:before-cache", this.beforeCache);
        if (this.hasDesktopSidebarTarget && this.boundHandleToggle) {
            this.desktopSidebarTarget.removeEventListener("toggle", this.boundHandleToggle);
        }
    }

    handleToggle(event) {
        // Save the current state to localStorage
        localStorage.setItem(this.storageKeyValue, this.desktopSidebarTarget.open.toString());
    }

    open() {
        if (this.hasDesktopSidebarTarget) {
            this.desktopSidebarTarget.open = true;
        }
    }

    close() {
        if (this.hasDesktopSidebarTarget) {
            this.desktopSidebarTarget.open = false;
        }
    }

    toggle() {
        if (this.hasDesktopSidebarTarget) {
            this.desktopSidebarTarget.open = !this.desktopSidebarTarget.open;
        }
    }

    openMobile(event) {
        if (!this.hasMobileSidebarTarget || this.mobileSidebarTarget.open) return;
        clearTimeout(this.closeTimer);
        this.returnFocus = event?.currentTarget || document.activeElement;
        const animate = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        if (this.hasMobileBackdropTarget) this.mobileBackdropTarget.style.opacity = animate ? "0" : "1";
        if (this.hasMobilePanelTarget) this.mobilePanelTarget.style.transform = animate ? "translateX(-100%)" : "translateX(0)";
        this.mobileSidebarTarget.showModal();
        if (this.hasMobileToggleTarget) this.mobileToggleTarget.setAttribute("aria-expanded", "true");
        this.openFrame = requestAnimationFrame(() => {
            if (!this.mobileSidebarTarget.open) return;
            if (this.hasMobileBackdropTarget) this.mobileBackdropTarget.style.opacity = "1";
            if (this.hasMobilePanelTarget) this.mobilePanelTarget.style.transform = "translateX(0)";
        });
    }

    cancelMobile(event) {
        event.preventDefault();
        this.closeMobile();
    }

    keepMobileFocus(event) {
        if (event.key !== "Tab") return;
        const items = Array.from(this.mobileSidebarTarget.querySelectorAll(
            'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex="0"]'
        )).filter((element) => element.tabIndex >= 0 && element.getClientRects().length);
        const first = items[0];
        const last = items.at(-1);
        if (first && event.shiftKey && document.activeElement === first) {
            event.preventDefault();
            last.focus();
        } else if (last && !event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first.focus();
        }
    }

    closeMobile(animate = true) {
        clearTimeout(this.closeTimer);
        cancelAnimationFrame(this.openFrame);
        if (!this.hasMobileSidebarTarget || !this.mobileSidebarTarget.open) return;
        if (this.hasMobileToggleTarget) this.mobileToggleTarget.setAttribute("aria-expanded", "false");
        const finish = () => {
            this.mobileSidebarTarget.close();
            if (this.returnFocus?.isConnected && this.returnFocus.getClientRects().length) {
                this.returnFocus.focus({ preventScroll: true });
            }
            this.returnFocus = null;
        };
        if (animate && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
            if (this.hasMobileBackdropTarget) this.mobileBackdropTarget.style.opacity = "0";
            if (this.hasMobilePanelTarget) this.mobilePanelTarget.style.transform = "translateX(-100%)";
            this.closeTimer = setTimeout(finish, 300);
        } else {
            finish();
        }
    }
}
