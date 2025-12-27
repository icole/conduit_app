import { Controller } from "@hotwired/stimulus"

// Handles swipe gestures on elements
// Usage:
//   data-controller="swipe"
//   data-swipe-url-value="/tasks/123/move_to_backlog"
//   data-swipe-method-value="patch"
//   data-swipe-direction-value="left" (default)
//   data-swipe-threshold-value="100" (pixels, default)
export default class extends Controller {
  static values = {
    url: String,
    method: { type: String, default: "patch" },
    direction: { type: String, default: "left" },
    threshold: { type: Number, default: 100 }
  }

  connect() {
    this.startX = 0
    this.startY = 0
    this.currentX = 0
    this.isSwiping = false
    this.isHorizontalSwipe = null
    this.sortableDragging = false

    this.boundHandleTouchStart = this.handleTouchStart.bind(this)
    this.boundHandleTouchMove = this.handleTouchMove.bind(this)
    this.boundHandleTouchEnd = this.handleTouchEnd.bind(this)

    this.element.addEventListener("touchstart", this.boundHandleTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.boundHandleTouchMove, { passive: false })
    this.element.addEventListener("touchend", this.boundHandleTouchEnd)

    // Expose controller for sortable to access
    this.element.swipeController = this
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.boundHandleTouchStart)
    this.element.removeEventListener("touchmove", this.boundHandleTouchMove)
    this.element.removeEventListener("touchend", this.boundHandleTouchEnd)
    delete this.element.swipeController
  }

  handleTouchStart(event) {
    // Check if element is being sorted (has sortable ghost class)
    if (this.element.classList.contains('sortable-ghost') ||
        this.element.classList.contains('sortable-chosen')) {
      this.sortableDragging = true
      return
    }

    this.startX = event.touches[0].clientX
    this.startY = event.touches[0].clientY
    this.currentX = 0
    this.isSwiping = true
    this.sortableDragging = false
    this.isHorizontalSwipe = null
    this.element.style.transition = "none"
  }

  handleTouchMove(event) {
    if (!this.isSwiping || this.sortableDragging) return

    const deltaX = event.touches[0].clientX - this.startX
    const deltaY = event.touches[0].clientY - this.startY

    // Determine if this is a horizontal or vertical swipe on first significant movement
    if (this.isHorizontalSwipe === null && (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10)) {
      this.isHorizontalSwipe = Math.abs(deltaX) > Math.abs(deltaY)
    }

    // Only handle horizontal swipes
    if (!this.isHorizontalSwipe) return

    event.preventDefault()

    // Only allow swipe in the configured direction
    const isCorrectDirection = this.directionValue === "left" ? deltaX < 0 : deltaX > 0
    if (!isCorrectDirection) {
      this.currentX = 0
      this.element.style.transform = "translateX(0)"
      return
    }

    this.currentX = deltaX
    const clampedX = this.directionValue === "left"
      ? Math.max(deltaX, -this.thresholdValue * 1.5)
      : Math.min(deltaX, this.thresholdValue * 1.5)

    this.element.style.transform = `translateX(${clampedX}px)`

    // Add visual feedback when threshold is reached
    const progress = Math.min(Math.abs(deltaX) / this.thresholdValue, 1)
    this.element.style.opacity = 1 - (progress * 0.3)
  }

  handleTouchEnd() {
    if (!this.isSwiping || this.sortableDragging) {
      this.sortableDragging = false
      return
    }
    this.isSwiping = false

    this.element.style.transition = "transform 0.2s ease-out, opacity 0.2s ease-out"

    const swipeDistance = Math.abs(this.currentX)
    const isCorrectDirection = this.directionValue === "left" ? this.currentX < 0 : this.currentX > 0

    if (swipeDistance >= this.thresholdValue && isCorrectDirection) {
      // Animate out and trigger action
      const exitX = this.directionValue === "left" ? "-100%" : "100%"
      this.element.style.transform = `translateX(${exitX})`
      this.element.style.opacity = "0"

      setTimeout(() => this.triggerAction(), 200)
    } else {
      // Snap back
      this.element.style.transform = "translateX(0)"
      this.element.style.opacity = "1"
    }
  }

  triggerAction() {
    if (!this.urlValue) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: this.methodValue.toUpperCase(),
      headers: {
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
      },
      credentials: "same-origin"
    }).then(response => {
      if (response.ok) {
        return response.text()
      }
    }).then(html => {
      if (html) {
        Turbo.renderStreamMessage(html)
      }
    }).catch(() => {
      // Reset on error
      this.element.style.transform = "translateX(0)"
      this.element.style.opacity = "1"
    })
  }
}
