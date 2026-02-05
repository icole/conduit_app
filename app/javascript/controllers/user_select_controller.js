import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["input", "display", "option", "webSelect", "nativeSelect"]

  static get shouldLoad() { return true }

  connect() {
    super.connect()

    if (this.enabled) {
      // Bridge is active — show native button, hide web select
      this.webSelectTarget.classList.add("hidden")
      this.nativeSelectTarget.classList.remove("hidden")
      // Disable the web select so it doesn't submit a competing value
      this.webSelectTarget.querySelector("select").disabled = true
    } else {
      // Web — disable the hidden field so it doesn't override the select
      this.inputTarget.disabled = true
    }
  }

  // Native bridge: show the native menu picker
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.enabled) {
      this.#showNativeMenu()
    }
  }

  // Web: handle native <select> change
  webChanged(event) {
    // The native <select> already sets the form value, nothing else needed
  }

  // Private

  #showNativeMenu() {
    const items = this.optionTargets.map((opt, index) => ({
      title: opt.dataset.name,
      index: index
    }))

    const title = "Assign to"
    this.send("display", { title, items }, (message) => {
      const selectedIndex = message.data.selectedIndex
      const option = this.optionTargets[selectedIndex]
      if (option) {
        const id = option.dataset.value
        const name = option.dataset.name
        this.inputTarget.value = id
        this.displayTarget.querySelector("span").textContent = name
      }
    })
  }
}
