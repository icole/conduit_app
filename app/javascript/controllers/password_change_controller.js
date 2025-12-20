import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-change"
export default class extends Controller {
  static targets = ["newPassword", "confirmPassword", "errorMessage", "submitButton"]

  connect() {
    this.validateMatch()
  }

  validateMatch() {
    const newPassword = this.newPasswordTarget.value
    const confirmPassword = this.confirmPasswordTarget.value

    if (confirmPassword === "") {
      // Clear error if confirmation field is empty
      this.errorMessageTarget.textContent = ""
      this.submitButtonTarget.disabled = false
      return
    }

    if (newPassword !== confirmPassword) {
      this.errorMessageTarget.textContent = "Passwords don't match"
      this.submitButtonTarget.disabled = true
      this.confirmPasswordTarget.classList.add("input-error")
    } else {
      this.errorMessageTarget.textContent = ""
      this.submitButtonTarget.disabled = false
      this.confirmPasswordTarget.classList.remove("input-error")
    }
  }
}