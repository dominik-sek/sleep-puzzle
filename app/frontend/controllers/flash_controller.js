import { Controller } from "@hotwired/stimulus";
import { showToast } from "./toast_controller";

// Bridges Rails flash messages (rendered by shared/_flash) into the toast stack.
// Reconnects on every Turbo visit and on turbo_stream replacements of #flash.
export default class extends Controller {
    static values = { messages: Array };

    connect() {
        this.messagesValue.forEach((message) => showToast(message));
    }
}
