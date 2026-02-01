import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["input", "display", "menu", "option"]

  // Always load — web uses the dropdown fallback, native uses the bridge
  static get shouldLoad() { return true }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.enabled) {
      this.#showNativeMenu()
    } else {
      this.menuTarget.classList.toggle("hidden")
    }
  }

  select(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.value
    const name = event.currentTarget.dataset.name
    this.#updateSelection(id, name, event.currentTarget)
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    super.connect()
    this._closeHandler = this.close.bind(this)
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("click", this._closeHandler)
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
        this.#updateSelection(id, name, option)
      }
    })
  }

  #updateSelection(id, name, selectedElement) {
    this.inputTarget.value = id
    this.displayTarget.querySelector("span").textContent = name
    this.menuTarget.classList.add("hidden")

    this.optionTargets.forEach(opt => {
      opt.classList.remove("bg-base-200", "font-semibold")
    })
    selectedElement.classList.add("bg-base-200", "font-semibold")
  }
}
