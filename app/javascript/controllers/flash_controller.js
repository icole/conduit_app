import { Controller } from "@hotwired/stimulus"

// A toast (layouts/_toast): hides itself after a few seconds, longer when
// it offers Undo, or when its close button is tapped.
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
    clearTimeout(this.timeout)
  }
}
