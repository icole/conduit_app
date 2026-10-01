import { Controller } from "@hotwired/stimulus"

// Apps with a native top bar (they register the "button" bridge component)
// present this form as a sheet. There it submits with Turbo and says so, and
// the server answers by telling the app to close the sheet and refresh the
// screen beneath. Elsewhere the form submits as a normal page, as before.
export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.adopt())
    this.observer.observe(document.documentElement, { attributeFilter: ["data-bridge-components"] })
    this.adopt()
  }

  disconnect() {
    this.observer.disconnect()
  }

  // The app announces its components once its bridge loads, which can be
  // after this form connects
  adopt() {
    const components = document.documentElement.dataset.bridgeComponents?.split(" ") ?? []
    if (!components.includes("button") || this.element.querySelector("input[name=sheet]")) return

    this.element.dataset.turbo = "true"
    this.element.dataset.turboFrame = "_top"
    const marker = document.createElement("input")
    Object.assign(marker, { type: "hidden", name: "sheet", value: "1" })
    this.element.append(marker)
    this.observer.disconnect()
  }
}
