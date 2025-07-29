import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { eventId: String }

  connect() {
    if (this.eventIdValue) {
      // Open the modal for the specified event
      this.openEventModal()
    }
  }

  openEventModal() {
    const eventId = this.eventIdValue
    const modalId = `event_${eventId.replace(/[^a-zA-Z0-9]/g, '_')}_modal`
    const modal = document.getElementById(modalId)
    
    if (modal) {
      // Close any other open modals first
      document.querySelectorAll('dialog[open]').forEach(openModal => {
        if (openModal.id !== modalId) {
          openModal.close()
        }
      })
      
      // Open the target modal
      modal.showModal()
    }
  }
}