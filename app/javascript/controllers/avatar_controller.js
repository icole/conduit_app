import { Controller } from "@hotwired/stimulus"

// user_avatar: when the photo can't load, show the initials instead.
export default class extends Controller {
  static targets = ["photo", "initials"]

  fallback() {
    this.photoTarget.remove()
    this.initialsTarget.hidden = false
  }
}
