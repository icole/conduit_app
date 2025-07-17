import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["refreshButton", "filesList", "loadingState", "errorState"]

  connect() {
    // Listen for drive sync updates
    document.addEventListener('drive-sync-update', this.handleSyncUpdate.bind(this))
  }

  disconnect() {
    document.removeEventListener('drive-sync-update', this.handleSyncUpdate.bind(this))
  }

  refresh() {
    this.setLoadingState(true)

    // Try WebSocket first
    if (window.driveSyncChannel) {
      window.driveSyncChannel.refreshFiles()
    } else {
      // Fallback to HTTP request
      this.refreshViaHttp()
    }
  }

  refreshViaHttp() {
    fetch('/dashboard/refresh_drive_files', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'error') {
        this.showError(data.message)
      }
    })
    .catch(error => {
      console.error('Error refreshing files:', error)
      this.showError('Failed to refresh files')
    })
  }

  handleSyncUpdate(event) {
    const data = event.detail

    switch (data.type) {
      case 'sync_started':
        this.setLoadingState(true)
        break
      case 'sync_completed':
        this.setLoadingState(false)
        this.updateFilesListWithHtml(data.html)
        break
      case 'sync_error':
        this.setLoadingState(false)
        this.showError(data.error)
        break
    }
  }

  setLoadingState(loading) {
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = loading
      const buttonText = this.refreshButtonTarget.querySelector('.button-text')
      const spinner = this.refreshButtonTarget.querySelector('.loading-spinner')

      if (loading) {
        if (buttonText) buttonText.textContent = 'Refreshing...'
        if (spinner) spinner.classList.remove('hidden')
      } else {
        if (buttonText) buttonText.textContent = 'Refresh'
        if (spinner) spinner.classList.add('hidden')
      }
    }

    if (this.hasLoadingStateTarget) {
      this.loadingStateTarget.classList.toggle('hidden', !loading)
    }

    // Hide files list when loading, show when not loading
    if (this.hasFilesListTarget) {
      this.filesListTarget.classList.toggle('hidden', loading)
    }
  }

  updateFilesListWithHtml(html) {
    if (this.hasFilesListTarget) {
      this.filesListTarget.innerHTML = html
      this.filesListTarget.classList.remove('hidden')
    }

    if (this.hasErrorStateTarget) {
      this.errorStateTarget.classList.add('hidden')
    }
  }

  showError(message) {
    if (this.hasErrorStateTarget) {
      this.errorStateTarget.innerHTML = `
        <div class="text-center py-4 text-error">
          <p class="text-sm">${message}</p>
        </div>
      `
      this.errorStateTarget.classList.remove('hidden')
    }
  }
}
