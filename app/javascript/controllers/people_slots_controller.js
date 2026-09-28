import { Controller } from "@hotwired/stimulus"

// "People needed" shows that many person pickers. A hidden picker is cleared,
// so a spot you took away doesn't still send someone.
export default class extends Controller {
  static targets = ["count", "slot"]

  update() {
    const count = parseInt(this.countTarget.value, 10) || 1

    this.slotTargets.forEach((slot, index) => {
      const shown = index < count
      slot.hidden = !shown
      if (shown) return

      slot.querySelectorAll("select").forEach((select) => { select.value = "" })
      slot.querySelectorAll("input[type=hidden]").forEach((input) => { input.value = "" })
      slot.querySelectorAll("[data-user-select-target='display'] span").forEach((span) => {
        span.textContent = slot.querySelector("[data-user-select-target='option'][data-value='']")?.dataset.name || "Unassigned"
      })
    })
  }
}
