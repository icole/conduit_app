// The iOS app's web view has no handler for JavaScript dialogs, so
// window.confirm() quietly returns false and every data-turbo-confirm action
// (Remove, Close project, Can't do it, Delete...) did nothing. In the apps,
// Turbo asks with an in-page dialog instead. The browser keeps its own.
import { Turbo } from "@hotwired/turbo-rails"

const inNativeApp = /(Turbo|Hotwire) Native/.test(navigator.userAgent)

function confirmInPage(message) {
  return new Promise((resolve) => {
    const dialog = document.createElement("dialog")
    dialog.className = "modal modal-bottom sm:modal-middle"
    dialog.innerHTML = `
      <div class="modal-box">
        <p class="text-base" data-message></p>
        <form method="dialog" class="modal-action">
          <button value="cancel" class="btn btn-ghost">Cancel</button>
          <button value="confirm" class="btn btn-primary">OK</button>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop"><button value="cancel">Close</button></form>`
    dialog.querySelector("[data-message]").textContent = message

    dialog.addEventListener("close", () => {
      resolve(dialog.returnValue === "confirm")
      dialog.remove()
    }, { once: true })

    document.body.appendChild(dialog)
    dialog.showModal()
  })
}

if (inNativeApp) {
  Turbo.config.forms.confirm = confirmInPage
}
