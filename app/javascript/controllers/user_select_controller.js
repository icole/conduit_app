import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display", "menu", "option"]

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  select(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.value
    const name = event.currentTarget.dataset.name
    this.inputTarget.value = id
    this.displayTarget.querySelector("span").textContent = name
    this.menuTarget.classList.add("hidden")

    this.optionTargets.forEach(opt => {
      opt.classList.remove("bg-base-200", "font-semibold")
    })
    event.currentTarget.classList.add("bg-base-200", "font-semibold")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
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
