import { Controller } from "@hotwired/stimulus"

// Swaps a read-only panel for an edit form and back.
export default class extends Controller {
  static targets = ["display", "form"]

  toggle(event) {
    event?.preventDefault()
    this.displayTarget.classList.toggle("hidden")
    this.formTarget.classList.toggle("hidden")
  }

  hide(event) {
    event?.preventDefault()
    this.displayTarget.classList.remove("hidden")
    this.formTarget.classList.add("hidden")
  }
}
