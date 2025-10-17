import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="document-selector"
export default class extends Controller {
  static targets = ["searchInput", "hiddenInput", "dropdown", "option", "moreIndicator"]

  connect() {
    // Initialize by hiding dropdown
    this.dropdownTarget.classList.add('hidden')
  }

  showDropdown() {
    this.dropdownTarget.classList.remove('hidden')
    this.filterOptions(this.searchInputTarget.value)
  }

  hideDropdown() {
    this.dropdownTarget.classList.add('hidden')
  }

  filterOnInput(event) {
    const searchTerm = event.target.value.toLowerCase()
    this.filterOptions(searchTerm)
    this.dropdownTarget.classList.remove('hidden')
  }

  selectOption(event) {
    const option = event.currentTarget
    const id = option.dataset.id
    const title = option.dataset.title

    this.searchInputTarget.value = title
    this.hiddenInputTarget.value = id
    this.hideDropdown()
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }

  filterOptions(searchTerm) {
    let visibleCount = 0
    const isSearching = searchTerm.length > 0

    this.optionTargets.forEach(option => {
      const title = option.dataset.title.toLowerCase()
      const hasInitiallyHidden = option.classList.contains('initially-hidden')

      if (title.includes(searchTerm)) {
        // Show if matches search OR if no search and in first 6
        if (isSearching || !hasInitiallyHidden) {
          option.style.display = 'block'
          visibleCount++
        } else {
          option.style.display = 'none'
        }
      } else {
        option.style.display = 'none'
      }
    })

    // Show/hide the "more" indicator
    if (this.hasMoreIndicatorTarget) {
      if (isSearching) {
        this.moreIndicatorTarget.style.display = 'none'
      } else {
        this.moreIndicatorTarget.style.display = 'block'
      }
    }

    // Hide dropdown if no matches
    if (visibleCount === 0) {
      this.hideDropdown()
    }
  }
}
