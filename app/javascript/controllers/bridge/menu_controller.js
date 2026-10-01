import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// A row's "more" menu as the platform's own sheet. Each item target is a real
// link or button on the page; picking it natively clicks that element.
// Only apps with a native top bar (the "button" component) use it; the others
// keep the page's own dropdown.
export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["item"]
  static values = { title: String }

  get native() {
    const components = document.documentElement.dataset.bridgeComponents?.split(" ") ?? []
    return this.enabled && components.includes("button")
  }

  show(event) {
    // A picked item's own click bubbles up here; let it through
    if (!this.native || this.itemTargets.some((item) => item.contains(event.target))) return
    event.preventDefault()

    const items = this.itemTargets.map((item, index) => ({
      title: item.dataset.bridgeTitle || item.textContent.trim(),
      destructive: item.dataset.bridgeDestructive === "true",
      index
    }))
    this.send("display", { title: this.titleValue, items }, (message) => {
      this.itemTargets[message.data.selectedIndex]?.click()
    })
  }
}
