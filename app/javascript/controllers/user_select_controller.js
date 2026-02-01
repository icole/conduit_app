import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display", "menu", "option"]
  static values = { open: { type: Boolean, default: false } }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  select(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.value
    const name = event.currentTarget.dataset.name
    this.inputTarget.value = id
    this.displayTarget.textContent = name
    this.openValue = false

    // Update active styling
    this.optionTargets.forEach(opt => opt.classList.remove("active"))
    event.currentTarget.classList.add("active")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.openValue = false
    }
  }

  openValueChanged() {
    if (this.openValue) {
      this.menuTarget.classList.remove("hidden")
    } else {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    this._closeHandler = this.close.bind(this)
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._closeHandler)
  }
}
