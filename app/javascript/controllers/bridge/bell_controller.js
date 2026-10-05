import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// The notification bell in the apps' top bar (CON-72). Every page sends its
// count of what needs you; tapping the bell clicks this link to Notifications.
export default class extends BridgeComponent {
  static component = "bell"

  connect() {
    super.connect()
    const { bridgeTitle: title, bridgeCount: count } = this.element.dataset
    this.send("connect", { title, count: Number(count) || 0 }, () => this.element.click())
  }
}
