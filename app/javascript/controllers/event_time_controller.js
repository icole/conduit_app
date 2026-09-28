import { Controller } from "@hotwired/stimulus"

// The event form's date and times. Moving the start moves the end with it,
// keeping the event's length; changing the end sets a new length. One-day
// events have a single date; "Ends on a different day" adds an end date.
export default class extends Controller {
  static targets = ["startDate", "startTime", "endTime", "endDate", "endDateField", "multiDay", "startDateLabel"]

  connect() {
    this.duration = this.minutesBetween(this.start(), this.end()) ?? 60
    if (this.duration <= 0) this.duration = 60
  }

  startDateChanged() {
    // A multi-day event keeps its length; a one-day event has no end date to move
    if (this.multiDayTarget.checked) this.moveEnd()
  }

  startTimeChanged() {
    this.moveEnd()
  }

  endChanged() {
    const minutes = this.minutesBetween(this.start(), this.end())
    if (minutes && minutes > 0) this.duration = minutes
  }

  // Unticking leaves the times as they are, for you to adjust
  multiDayChanged() {
    this.showEndDate(this.multiDayTarget.checked)
    this.endChanged()
  }

  showEndDate(multiDay) {
    this.multiDayTarget.checked = multiDay
    this.endDateFieldTarget.hidden = !multiDay
    this.endDateTarget.disabled = !multiDay
    this.startDateLabelTarget.textContent = multiDay ? "Starts on *" : "Date *"
    if (multiDay && !this.endDateTarget.value) this.endDateTarget.value = this.startDateTarget.value
  }

  // Put the end `duration` minutes after the start
  moveEnd() {
    const start = this.start()
    if (!start) return

    const end = new Date(start.getTime() + this.duration * 60000)
    this.endTimeTarget.value = `${this.pad(end.getHours())}:${this.pad(end.getMinutes())}`
    // Running past midnight makes it a two-day event
    if (end.toDateString() !== start.toDateString()) this.showEndDate(true)
    if (this.multiDayTarget.checked) {
      this.endDateTarget.value = `${end.getFullYear()}-${this.pad(end.getMonth() + 1)}-${this.pad(end.getDate())}`
    }
  }

  start() {
    return this.dateTime(this.startDateTarget.value, this.startTimeTarget.value)
  }

  end() {
    const date = this.multiDayTarget.checked ? this.endDateTarget.value : this.startDateTarget.value
    return this.dateTime(date, this.endTimeTarget.value)
  }

  dateTime(date, time) {
    if (!date || !time) return null
    const [year, month, day] = date.split("-").map(Number)
    const [hours, minutes] = time.split(":").map(Number)
    return new Date(year, month - 1, day, hours, minutes)
  }

  minutesBetween(start, end) {
    if (!start || !end) return null
    return Math.round((end - start) / 60000)
  }

  pad(number) {
    return String(number).padStart(2, "0")
  }
}
