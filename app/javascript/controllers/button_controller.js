import { Controller } from "@hotwired/stimulus"

// Handles loading state for buttons
export default class extends Controller {
  static targets = ["text", "icon", "spinner"]

  submitWithLoading(event) {
    // Prevent multiple form submissions
    if (this.element.classList.contains("submitting")) {
      event.preventDefault()
      return
    }
    
    // Mark form as being submitted
    this.element.classList.add("submitting")
    
    // Disable the button
    const button = event.currentTarget
    button.disabled = true
    
    // Show loading state
    if (this.hasTextTarget) {
      this.textTarget.textContent = "Processing..."
    }
    
    if (this.hasIconTarget && this.hasSpinnerTarget) {
      this.iconTarget.classList.add("hidden")
      this.spinnerTarget.classList.remove("hidden")
    }
    
    // Allow the form to submit
  }
}
