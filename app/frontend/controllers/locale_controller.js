import { Controller } from "@hotwired/stimulus";

// Keeps <html lang> honest across Turbo navigations.
//
// Turbo Drive swaps the <body> and merges the <head>, but never touches the
// attributes on <html> itself — so after switching language the document still
// claimed the old one. Nothing visible breaks, but a screen reader keeps reading
// English copy with Polish pronunciation rules, and any script that trusts
// document.documentElement.lang gets a stale answer.
//
// Attached to <body>, so it reconnects on every navigation.
export default class extends Controller {
    static values = { tag: String };

    connect() {
        if (this.tagValue) document.documentElement.lang = this.tagValue;
    }
}
