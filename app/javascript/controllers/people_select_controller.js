import { Controller } from "@hotwired/stimulus"

// The people dropdown on task forms: the closed field reads out who's ticked,
// and tapping anywhere else closes the list.
export default class extends Controller {
  static targets = ["dropdown", "summary"]
  static values = { empty: String }

  connect() {
    this.closeIfOutside = this.closeIfOutside.bind(this)
    document.addEventListener("click", this.closeIfOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeIfOutside)
  }

  update() {
    const names = Array.from(this.element.querySelectorAll("input[type=checkbox]:checked"), (box) => box.dataset.name)
    this.summaryTarget.textContent = names.length ? names.join(", ") : this.emptyValue
  }

  closeIfOutside(event) {
    if (this.dropdownTarget.open && !this.element.contains(event.target)) this.dropdownTarget.open = false
  }
}
