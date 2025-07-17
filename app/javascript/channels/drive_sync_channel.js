import consumer from "channels/consumer"

const driveSyncChannel = consumer.subscriptions.create("DriveSyncChannel", {
  connected() {
    console.log("Connected to DriveSyncChannel")
  },

  disconnected() {
    console.log("Disconnected from DriveSyncChannel")
  },

  received(data) {
    console.log("Received drive sync data:", data)

    // Dispatch custom event that the Stimulus controller can listen to
    const event = new CustomEvent('drive-sync-update', {
      detail: data
    })
    document.dispatchEvent(event)
  },

  refreshFiles() {
    this.perform('refresh_files')
  }
})

// Make it globally available
window.driveSyncChannel = driveSyncChannel

export default driveSyncChannel
