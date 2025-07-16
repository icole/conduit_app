import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Topics controller connected")
  }
  
  showForm() {
    document.getElementById('new-topic-form').classList.remove('hidden')
  }
  
  hideForm() {
    document.getElementById('new-topic-form').classList.add('hidden')
  }
}
