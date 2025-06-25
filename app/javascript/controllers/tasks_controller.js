import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Hide the form by default unless there are errors
    if (!document.querySelector("#new-task-form .alert")) {
      document.getElementById("new-task-form").classList.add("hidden");
    }
  }

  showForm(event) {
    event.preventDefault();
    document.getElementById("new-task-form").classList.remove("hidden");
  }

  hideForm(event) {
    event.preventDefault();
    document.getElementById("new-task-form").classList.add("hidden");
  }
}