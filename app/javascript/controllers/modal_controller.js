import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Prevent scrolling on the body when modal is open
    document.body.classList.add('overflow-hidden')

    // Listen for escape key to close modal
    document.addEventListener('keydown', this.handleKeyDown)
  }

  disconnect() {
    document.body.classList.remove('overflow-hidden')
    document.removeEventListener('keydown', this.handleKeyDown)
  }

  handleKeyDown = (event) => {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  // This is now a no-op as the link will handle the turbo frame request
  // The controller is used only for managing the modal's state once it's open
  open(event) {
    // We don't need to prevent default - we want the turbo frame request to proceed
    // The modal will open when the turbo_frame response is received
  }

  close() {
    // When the modal is closed, we need to clear the frame
    const frame = document.getElementById('modal')
    if (frame) {
      frame.innerHTML = ''
    }
    document.body.classList.remove('overflow-hidden')
  }
}
