import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "startTime", "endDate", "endTime"]

  startChanged() {
    const startDate = this.startDateTarget.value
    const startTime = this.startTimeTarget.value

    if (startDate && startTime && !this.endTimeTarget.value) {
      // Auto-set end date to same day
      this.endDateTarget.value = startDate

      // Auto-set end time to 1 hour later
      const [hours, minutes] = startTime.split(":").map(Number)
      const endHours = (hours + 1) % 24
      this.endTimeTarget.value = `${String(endHours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`
    } else if (startDate && !this.endDateTarget.value) {
      this.endDateTarget.value = startDate
    }
  }
}
