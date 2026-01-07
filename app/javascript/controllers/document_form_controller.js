import { Controller } from "@hotwired/stimulus"

// Handles toggling between native and Google Drive document types in the form
export default class extends Controller {
  static targets = ["googleDriveFields", "nativeHint"]

  connect() {
    this.toggleStorageType()
  }

  toggleStorageType() {
    const selectedType = this.element.querySelector('input[name="document[storage_type]"]:checked')?.value

    if (selectedType === "google_drive") {
      this.googleDriveFieldsTarget.classList.remove("hidden")
      this.nativeHintTarget.classList.add("hidden")
    } else {
      this.googleDriveFieldsTarget.classList.add("hidden")
      this.nativeHintTarget.classList.remove("hidden")
    }
  }
}
