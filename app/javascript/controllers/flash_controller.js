import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["close"]

    connect() {
        this.timeout = setTimeout(() => this.dismiss(), 3000)
    }

    dismiss() {
        this.element.style.display = "none"
        clearTimeout(this.timeout)
    }
}