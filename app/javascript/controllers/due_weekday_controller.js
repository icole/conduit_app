import { Controller } from "@hotwired/stimulus"

// "Due on" (a day of the week) only means something for weekly and
// every-two-weeks tasks, so it shows only when one of those is picked.
export default class extends Controller {
  static targets = ["frequency", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const weekly = ["weekly", "biweekly"].includes(this.frequencyTarget.value)
    this.fieldTargets.forEach((el) => { el.hidden = !weekly })
  }
}
