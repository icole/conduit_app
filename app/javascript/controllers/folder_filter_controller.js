import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="folder-filter"
// Filters radio-button folder options in the move-to-folder modal
export default class extends Controller {
  static targets = ["search", "option"]

  filter() {
    const term = this.searchTarget.value.toLowerCase()

    this.optionTargets.forEach(option => {
      const text = option.textContent.toLowerCase()
      const isRoot = option.dataset.root === "true"

      if (isRoot || text.includes(term)) {
        option.style.display = ""
      } else {
        option.style.display = "none"
      }
    })
  }
}
