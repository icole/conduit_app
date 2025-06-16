import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        console.log("Posts controller connected")
    }

    showForm(event) {
        event.preventDefault()
        document.getElementById("new-post-form").classList.remove("hidden")
    }

    cancelForm(event) {
        event.preventDefault()
        document.getElementById("new-post-form").classList.add("hidden")
    }
}