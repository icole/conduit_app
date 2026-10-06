import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// The notification bell in the apps' top bar (CON-72). Every page sends its
// count of what needs you; tapping the bell clicks this link to Notifications.
// The count is freshened when the app asks (a sheet closed, back from another
// screen) and after any form on the page (claiming or completing a task), as
// well as live over Action Cable (BellBroadcastJob), which replaces this link.
export default class extends BridgeComponent {
  static component = "bell"

  connect() {
    super.connect()
    this.refreshAfterSubmit = () => this.refresh()
    document.addEventListener("turbo:submit-end", this.refreshAfterSubmit)
    this.sendCount(this.element.dataset.bridgeCount)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this.refreshAfterSubmit)
    super.disconnect()
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
    if (!response.ok) return

    const { count } = await response.json()
    this.element.dataset.bridgeCount = count
    this.sendCount(count)
  }
}
