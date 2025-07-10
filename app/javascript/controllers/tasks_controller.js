import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const form = document.getElementById("new-task-form");
    // Hide the form by default unless there are errors
    if (form && !form.querySelector(".alert")) {
      form.classList.add("hidden");
    }
  }

  showForm(event) {
    event.preventDefault();
    const form = document.getElementById("new-task-form");
    if (form) form.classList.remove("hidden");
  }

  hideForm(event) {
    event.preventDefault();
    const form = document.getElementById("new-task-form");
    if (form) form.classList.add("hidden");
  }
}