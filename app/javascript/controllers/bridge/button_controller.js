import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// The page's main action as a native toolbar button; tapping it clicks this one.
export default class extends BridgeComponent {
  static component = "button"

  connect() {
    super.connect()
    const { bridgeTitle: title, bridgeImage: image } = this.element.dataset
    this.send("connect", { title, image }, () => this.element.click())
  }
}
