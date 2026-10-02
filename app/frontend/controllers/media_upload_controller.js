import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["input", "progress", "error", "submit"];
    static values = {
        targetType: String, targetId: Number, extensions: Array, maxBytes: Number,
        createUrl: String, chunkUrlTemplate: String, completeUrlTemplate: String
    };

    validate() {
        this.clearError();
        const file = this.inputTarget.files[0];
        if (!file) return false;
        const extension = file.name.split(".").pop().toLowerCase();
        if (!this.extensionsValue.includes(extension)) return this.reject(`Dozwolone formaty: ${this.extensionsValue.join(", ")}.`);
        if (file.size > this.maxBytesValue) return this.reject(`Plik jest za duży. Limit: ${Math.round(this.maxBytesValue / 1048576)} MB.`);
        if (file.size === 0) return this.reject("Plik jest pusty.");
        return true;
    }

    async upload() {
        if (!this.validate()) return;
        const file = this.inputTarget.files[0];
        const token = document.querySelector('meta[name="csrf-token"]')?.content;
        this.submitTarget.disabled = true;
        this.progressTarget.classList.remove("hidden");
        try {
            const chunkBytes = 64 * 1024 * 1024;
            const count = Math.ceil(file.size / chunkBytes);
            const session = await this.postJson(this.createUrlValue, {
                target_type: this.targetTypeValue, target_id: this.targetIdValue,
                filename: file.name, byte_size: file.size, chunk_count: count
            }, token);
            for (let index = 0; index < count; index++) {
                const slice = file.slice(index * chunkBytes, Math.min((index + 1) * chunkBytes, file.size));
                const url = this.chunkUrlTemplateValue.replace("UPLOAD_ID", session.id).replace("CHUNK_INDEX", index);
                let sent = false;
                for (let attempt = 0; attempt < 3 && !sent; attempt++) {
                    try {
                        await this.putChunk(url, slice, token, index, count);
                        sent = true;
                    } catch (error) {
                        if (attempt === 2) throw error;
                        await new Promise(resolve => setTimeout(resolve, (attempt + 1) * 1000));
                    }
                }
            }
            const result = await this.postJson(this.completeUrlTemplateValue.replace("UPLOAD_ID", session.id), {}, token);
            window.location.assign(result.redirect);
        } catch (error) {
            this.reject(error.message || "Nie udało się wysłać pliku.");
            this.submitTarget.disabled = false;
        }
    }

    async postJson(url, body, token) {
        const response = await fetch(url, {
            method: "POST", credentials: "same-origin",
            headers: { "Content-Type": "application/json", "X-CSRF-Token": token, "Accept": "application/json" },
            body: JSON.stringify(body)
        });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "Nie udało się zapisać pliku.");
        return result;
    }

    putChunk(url, blob, token, index, count) {
        return new Promise((resolve, reject) => {
            const request = new XMLHttpRequest();
            request.open("PUT", url);
            request.setRequestHeader("X-CSRF-Token", token);
            request.setRequestHeader("Content-Type", "application/octet-stream");
            request.upload.onprogress = event => {
                if (event.lengthComputable) this.progressTarget.value = Math.round(((index + event.loaded / event.total) / count) * 100);
            };
            request.onload = () => request.status === 204 ? resolve() : reject(new Error(`Wysyłanie części ${index + 1} nie powiodło się (HTTP ${request.status}).`));
            request.onerror = () => reject(new Error("Przerwano połączenie podczas wysyłania."));
            request.send(blob);
        });
    }

    reject(message) {
        this.errorTarget.textContent = message;
        this.errorTarget.classList.remove("hidden");
        return false;
    }

    clearError() {
        this.errorTarget.textContent = "";
        this.errorTarget.classList.add("hidden");
    }
}
