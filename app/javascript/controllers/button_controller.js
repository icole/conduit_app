import { Controller } from "@hotwired/stimulus"

// Handles loading state for buttons
export default class extends Controller {
  static targets = ["text", "icon", "spinner"]
  
  connect() {
    // Reset the form if it was previously in a loading state (e.g., on browser back)
    this.resetState()
  }

  submitWithLoading() {
    // Find the button element
    const button = this.element.querySelector('button[type="submit"]')
    if (!button) return
    
    // Only process if not already submitting
    if (button.disabled) return
    
    // Disable the button to prevent multiple clicks
    button.disabled = true
    
    // Show loading state
    if (this.hasTextTarget) {
      // Store original text for potential reset
      this.originalText = this.textTarget.textContent
      this.textTarget.textContent = "Processing..."
    }
    
    if (this.hasIconTarget && this.hasSpinnerTarget) {
      this.iconTarget.classList.add("hidden")
      this.spinnerTarget.classList.remove("hidden")
    }
    
    // Add listener to handle navigation away from page
    window.addEventListener('popstate', this.resetState.bind(this))
    window.addEventListener('beforeunload', this.resetState.bind(this))
  }
  
  resetState() {
    const button = this.element.querySelector('button[type="submit"]')
    if (!button) return
    
    button.disabled = false
    
    if (this.hasTextTarget && this.originalText) {
      this.textTarget.textContent = this.originalText
    }
    
    if (this.hasIconTarget && this.hasSpinnerTarget) {
      this.iconTarget.classList.remove("hidden")
      this.spinnerTarget.classList.add("hidden")
    }
  }
}
