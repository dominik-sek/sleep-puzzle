import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source", "button"];

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value);
      this.buttonTarget.textContent = "Skopiowano";
    } catch {
      this.sourceTarget.select();
      this.buttonTarget.textContent = "Zaznaczono link";
    }
  }
}
