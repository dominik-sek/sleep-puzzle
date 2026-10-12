import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "gallery"];
  static values = {
    options: Object,
    labels: Object,
    gallerySelector: String,
    showDownloadButton: { type: Boolean, default: true },
    showZoomIndicator: { type: Boolean, default: true },
    showDotsIndicator: { type: Boolean, default: true },
  };

  connect() {
    this.pendingOpen = null;
    this.setupGallery();
  }

  setupGallery() {
    if (this.hasGalleryTarget) {
      this.boundHandleGalleryClick = this.handleGalleryClick.bind(this);
      this.galleryTarget.addEventListener("click", this.boundHandleGalleryClick);
    } else if (this.hasTriggerTarget) {
      this.boundHandleSingleClick = this.handleSingleClick.bind(this);
      this.triggerTargets.forEach((trigger) => {
        trigger.addEventListener("click", this.boundHandleSingleClick);
      });
    }
  }

  handleGalleryClick(e) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button > 0) return;
    const clickedElement = e.target.closest("a[data-pswp-src]");
    if (!clickedElement) return;

    e.preventDefault();

    const galleryElements = this.galleryTarget.querySelectorAll("a[data-pswp-src]");
    const items = Array.from(galleryElements).map((el) => this.getItemData(el));
    const clickedIndex = Array.from(galleryElements).indexOf(clickedElement);

    this.openPhotoSwipe(items, clickedIndex, clickedElement);
  }

  handleSingleClick(e) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button > 0) return;
    e.preventDefault();
    const clickedElement = e.currentTarget;
    const items = [this.getItemData(clickedElement)];
    this.openPhotoSwipe(items, 0, clickedElement);
  }

  getItemData(element) {
    const item = {
      src: element.dataset.pswpSrc || element.href,
      width: parseInt(element.dataset.pswpWidth) || 0,
      height: parseInt(element.dataset.pswpHeight) || 0,
      alt: element.dataset.pswpAlt || "",
    };

    // Add caption if exists
    const caption = element.dataset.pswpCaption;
    if (caption) {
      item.caption = caption;
    }

    // If dimensions not provided, we'll need to load them
    if (!item.width || !item.height) {
      // Try to get dimensions from the thumbnail if it's already loaded
      const thumbnail = element.querySelector("img");
      if (thumbnail && thumbnail.complete && thumbnail.naturalWidth) {
        // Calculate aspect ratio from thumbnail
        const aspectRatio = thumbnail.naturalWidth / thumbnail.naturalHeight;

        // Determine a reasonable full-size dimension based on aspect ratio
        // This provides better defaults for different image types
        if (aspectRatio > 1.2) {
          // Landscape image
          item.width = 2400;
          item.height = Math.round(2400 / aspectRatio);
        } else if (aspectRatio < 0.8) {
          // Portrait image
          item.height = 2400;
          item.width = Math.round(2400 * aspectRatio);
        } else {
          // Square or nearly square
          item.width = 2000;
          item.height = 2000;
        }
      } else {
        // Conservative fallback when we have no information
        // Use a moderate size that works for most cases
        item.width = 1920;
        item.height = 1080; // 16:9 as a safe default
      }
      item.needsUpdate = true;
    }

    return item;
  }

  async openPhotoSwipe(items, index, trigger) {
    if (this.pendingOpen || this.viewer?.photoSwipe) return;

    const pending = {
      trigger,
      cursor: trigger.style.cursor,
      onKeyDown: (event) => {
        if (event.key === "Escape") this.cancelPendingOpen();
      },
    };
    this.pendingOpen = pending;
    trigger.setAttribute("aria-busy", "true");
    trigger.style.cursor = "wait";
    document.addEventListener("keydown", pending.onKeyDown);

    try {
      const { default: LightboxViewer } = await import("../lib/lightbox_viewer");
      if (this.pendingOpen !== pending) return;

      this.viewer ||= new LightboxViewer({
        element: this.element,
        labels: this.labelsValue,
        options: this.optionsValue,
        showDownloadButton: this.showDownloadButtonValue,
        showZoomIndicator: this.showZoomIndicatorValue,
        showDotsIndicator: this.showDotsIndicatorValue,
      });
      this.viewer.openPhotoSwipe(items, index);
    } catch {
      // A missing viewer chunk must not prevent access to the original image.
      if (this.pendingOpen === pending) window.location.assign(trigger.href);
    } finally {
      if (this.pendingOpen === pending) this.cancelPendingOpen();
    }
  }

  cancelPendingOpen() {
    if (!this.pendingOpen) return;
    const { trigger, cursor, onKeyDown } = this.pendingOpen;
    trigger.removeAttribute("aria-busy");
    trigger.style.cursor = cursor;
    document.removeEventListener("keydown", onKeyDown);
    this.pendingOpen = null;
  }

  disconnect() {
    this.cancelPendingOpen();
    this.viewer?.destroy();
    this.viewer = null;

    if (this.hasGalleryTarget) {
      this.galleryTarget.removeEventListener("click", this.boundHandleGalleryClick);
    } else if (this.hasTriggerTarget) {
      this.triggerTargets.forEach((trigger) => {
        trigger.removeEventListener("click", this.boundHandleSingleClick);
      });
    }
  }
}
