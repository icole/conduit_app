import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  showForm() {
    const form = this.element.querySelector("#comment-form")
    const button = this.element.querySelector("button[data-action*='showForm']")
    
    if (form) {
      form.classList.remove("hidden")
    }
    
    if (button) {
      button.style.display = "none"
    }
    
    // Focus on the textarea and scroll it into view
    if (form) {
      const textarea = form.querySelector("textarea")
      if (textarea) {
        textarea.focus()
        // Scroll the textarea into view with some padding
        textarea.scrollIntoView({ 
          behavior: 'smooth', 
          block: 'center' 
        })
      }
    }
  }

  hideForm() {
    const form = this.element.querySelector("#comment-form")
    const button = this.element.querySelector("button[data-action*='showForm']")
    
    if (form) {
      form.classList.add("hidden")
    }
    if (button) {
      button.style.display = "inline-flex"
    }
    
    // Clear the textarea
    if (form) {
      const textarea = form.querySelector("textarea")
      if (textarea) {
        textarea.value = ""
      }
    }
  }

  showReplyForm(event) {
    const commentId = event.currentTarget.dataset.commentId
    const replyForm = document.getElementById(`reply-form-${commentId}`)
    const replyButton = event.currentTarget
    
    // Hide all other reply forms
    document.querySelectorAll('[id^="reply-form-"]').forEach(form => {
      if (form.id !== `reply-form-${commentId}`) {
        form.classList.add('hidden')
      }
    })
    
    // Show all reply buttons
    document.querySelectorAll('button[data-action*="showReplyForm"]').forEach(btn => {
      btn.style.display = 'inline-flex'
    })
    
    // Show this reply form and hide its button
    replyForm.classList.remove('hidden')
    replyButton.style.display = 'none'
    
    // Focus on the textarea
    const textarea = replyForm.querySelector('textarea')
    if (textarea) {
      textarea.focus()
    }
  }

  hideReplyForm(event) {
    const commentId = event.currentTarget.dataset.commentId
    const replyForm = document.getElementById(`reply-form-${commentId}`)
    const replyButton = document.querySelector(`button[data-comment-id="${commentId}"][data-action*="showReplyForm"]`)
    
    replyForm.classList.add('hidden')
    if (replyButton) {
      replyButton.style.display = 'inline-flex'
    }
    
    // Clear the textarea
    const textarea = replyForm.querySelector('textarea')
    if (textarea) {
      textarea.value = ''
    }
  }
}
