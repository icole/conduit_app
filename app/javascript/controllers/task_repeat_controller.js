import { Controller } from "@hotwired/stimulus"

// On the Add task form, choosing how often a task repeats swaps the one-off
// fields (due date) for the recurring ones (priority), and relabels the
// assignee as the person responsible each period.
export default class extends Controller {
  static targets = ["repeats", "once", "recurring", "assigneeLabel"]

  connect() {
    this.toggle()
  }

  toggle() {
    const repeating = this.hasRepeatsTarget && this.repeatsTarget.value !== ""
    this.onceTargets.forEach((el) => { el.hidden = repeating })
    this.recurringTargets.forEach((el) => { el.hidden = !repeating })
    if (this.hasAssigneeLabelTarget) {
      this.assigneeLabelTarget.textContent = repeating ? "Responsible each period" : "Assign to"
    }
  }
}
