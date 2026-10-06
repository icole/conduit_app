import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// The notification bell in the apps' top bar (CON-72). Every page sends its
// count of what needs you; tapping the bell clicks this link to Notifications.
// The app asks for a refresh when the page shows again (a sheet closed, back
// from another screen), and the page sends the current count.
export default class extends BridgeComponent {
  static component = "bell"

  connect() {
    super.connect()
    this.sendCount(this.element.dataset.bridgeCount)
  }

  sendCount(count) {
    const title = this.element.dataset.bridgeTitle
    this.send("connect", { title, count: Number(count) || 0 }, (message) => {
      if (message.data.refresh) {
        this.refresh()
      } else {
        this.element.click()
      }
    })
  }

  async refresh() {
    const response = await fetch(this.element.dataset.bridgeCountUrl, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    })
    if (response.ok) this.sendCount((await response.json()).count)
  }
}
