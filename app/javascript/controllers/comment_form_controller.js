import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "submitButton"]

  connect() {
    this.adjustHeight()
  }

  // Auto-resize textarea as user types
  adjustHeight() {
    const textarea = this.textareaTarget
    textarea.style.height = 'auto'
    textarea.style.height = Math.min(textarea.scrollHeight, 150) + 'px'
  }

  // Submit form when Cmd+Enter or Ctrl+Enter is pressed
  submitOnEnter(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }

  // Reset form after successful submission
  reset() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ''
      this.adjustHeight()
    }
  }
}
