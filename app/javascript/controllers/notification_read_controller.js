import { Controller } from "@hotwired/stimulus"

// Marks a notification read as you follow its link (CON-72). The link goes
// straight to what it's about, so the apps show one transition instead of a
// redirect through /notifications/:id. keepalive lets it finish as the page
// changes.
export default class extends Controller {
  static values = { url: String }

  mark() {
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        "Accept": "application/json"
      },
      credentials: "same-origin",
      keepalive: true
    })
  }
}
