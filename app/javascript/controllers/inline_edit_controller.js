import { Controller } from "@hotwired/stimulus"

// Inline edit controller for document titles
export default class extends Controller {
  static targets = ["display", "form", "input"]
  static values = { url: String }

  edit(event) {
    event.preventDefault()
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel(event) {
    if (event) event.preventDefault()
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  async save(event) {
    event.preventDefault()
    const newTitle = this.inputTarget.value.trim()

    if (!newTitle) {
      this.cancel()
      return
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ document: { title: newTitle } })
      })

      if (response.ok) {
        // Update the display text
        this.displayTarget.querySelector("[data-title]").textContent = newTitle
        // Update the page title
        document.title = newTitle
        this.cancel()
      } else {
        console.error("Failed to save title")
      }
    } catch (error) {
      console.error("Error saving title:", error)
    }
  }

  // Handle escape key to cancel
  keydown(event) {
    if (event.key === "Escape") {
      this.cancel()
    }
  }
}
