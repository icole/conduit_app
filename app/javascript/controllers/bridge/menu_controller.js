import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// A row's "more" menu as the platform's own sheet. Each item target is a real
// link or button on the page; picking it natively clicks that element.
export default class extends BridgeComponent {
  static component = "menu"
  static targets = ["item"]
  static values = { title: String }

  show(event) {
    // A picked item's own click bubbles up here; let it through
    if (!this.enabled || this.itemTargets.some((item) => item.contains(event.target))) return
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
