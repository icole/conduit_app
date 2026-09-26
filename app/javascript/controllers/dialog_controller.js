import { Controller } from "@hotwired/stimulus"

// Opens a <dialog> that lives elsewhere in the page, addressed by id.
export default class extends Controller {
  static values = { id: String }

  open() {
    document.getElementById(this.idValue)?.showModal()
  }
}
