import { Controller } from "@hotwired/stimulus"

// Plus/minus buttons around a small number input, clamped to a range.
export default class extends Controller {
  static targets = ["count"]
  static values = { min: { type: Number, default: 0 }, max: { type: Number, default: 10 } }

  increment() {
    this.#change(1)
  }

  decrement() {
    this.#change(-1)
  }

  #change(delta) {
    const current = parseInt(this.countTarget.value, 10) || 0
    const next = Math.min(this.maxValue, Math.max(this.minValue, current + delta))
    this.countTarget.value = next
  }
}
