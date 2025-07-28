import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.initializeSortable()
  }

  initializeSortable() {
    if (this.hasListTarget) {
      this.sortable = Sortable.create(this.listTarget, {
        animation: 150,
        ghostClass: 'opacity-50',
        chosenClass: 'scale-105',
        dragClass: 'rotate-2',
        filter: 'button, a, .btn, input, select, textarea', // Exclude interactive elements
        preventOnFilter: false, // Allow clicking filtered elements
        onStart: (evt) => {
          // Drag started
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
  }
}