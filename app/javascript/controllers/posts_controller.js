import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["commentSection", "commentToggle"]

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

    toggleComments(event) {
        event.preventDefault()
        const postId = event.currentTarget.dataset.postId
        const commentSection = document.getElementById(`post-${postId}-comments`)
        console.log("Toggling comments for post ID:", postId, "found section:", !!commentSection)
        if (commentSection) {
            const wasHidden = commentSection.classList.contains("hidden")
            commentSection.classList.toggle("hidden")
            console.log("Comments section", wasHidden ? "expanded" : "collapsed")
        } else {
            console.error("Could not find comment section with ID:", `post-${postId}-comments`)
        }
    }
}
