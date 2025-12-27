import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.initializeSortable()

    // Reinitialize when Turbo updates the page
    this.boundReinitialize = this.reinitialize.bind(this)
    document.addEventListener("turbo:render", this.boundReinitialize)
  }

  reinitialize() {
    // Destroy existing sortable if it exists
    if (this.sortable) {
      this.sortable.destroy()
      this.sortable = null
    }
    // Reinitialize after a short delay to ensure DOM is ready
    setTimeout(() => this.initializeSortable(), 100)
  }

  initializeSortable() {
    if (this.hasListTarget) {
      this.sortable = Sortable.create(this.listTarget, {
        animation: 150,
        ghostClass: 'opacity-50',
        chosenClass: 'scale-105',
        dragClass: 'rotate-2',
        handle: '.badge-primary', // Only drag by the priority badge
        filter: 'button, a, .btn, input, select, textarea',
        preventOnFilter: false,
        delay: 150,
        delayOnTouchOnly: true,
        touchStartThreshold: 5,
        onStart: (evt) => {
          const swipeController = evt.item.swipeController
          if (swipeController) {
            swipeController.isSwiping = false
          }
        },
        onEnd: this.onEnd.bind(this)
      })
    }
  }

  onEnd(evt) {
    const taskId = evt.item.dataset.taskId
    const newIndex = evt.newIndex
    const oldIndex = evt.oldIndex

    if (taskId) {
      // Only update if the position actually changed
      if (newIndex !== oldIndex) {
        this.updatePriorityOrder(taskId, newIndex + 1)
      }
    }
  }

  async updatePriorityOrder(taskId, priorityOrder) {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      const response = await fetch(`/tasks/${taskId}/reorder`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({
          priority_order: priorityOrder
        })
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`Failed to update task order: ${response.status} - ${errorText}`)
      }
      
      // Check if there's any content to parse as JSON
      const responseText = await response.text()
      
      if (responseText) {
        try {
          const result = JSON.parse(responseText)
          // Update priority numbers in the UI
          this.updatePriorityNumbers()
        } catch (e) {
          // Even if response wasn't JSON, the reorder probably worked
          this.updatePriorityNumbers()
        }
      } else {
        // Update priority numbers even with empty response
        this.updatePriorityNumbers()
      }
    } catch (error) {
      console.error('Error updating task order:', error)
      // Optionally show a toast notification or reload the page
    }
  }

  updatePriorityNumbers() {
    // Find all task cards in the sortable list and update their priority numbers
    const taskCards = this.listTarget.querySelectorAll('[data-task-id]')
    
    taskCards.forEach((card, index) => {
      // Find the priority badge (the numbered badge)
      const priorityBadge = card.querySelector('.badge-primary')
      if (priorityBadge) {
        priorityBadge.textContent = index + 1
      }
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
    document.removeEventListener("turbo:render", this.boundReinitialize)
  }
}