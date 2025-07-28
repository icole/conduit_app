import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  openDatePicker(event) {
    // Prevent the default click behavior to override it
    event.preventDefault()
    
    try {
      // Focus the input first
      this.inputTarget.focus()
      
      // Use showPicker if available (modern browsers)
      if (typeof this.inputTarget.showPicker === 'function') {
        this.inputTarget.showPicker()
      }
      // For older browsers, the focus should be enough to show the picker
      
    } catch (error) {
      // If showPicker fails, at least the input is focused
    }
  }
}