import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { guest: Boolean }

  connect() {
    // nothing to do on connect
  }

  // Intercept form submit; if guest, show confirmation modal
  async submit(event) {
    if (!this.guestValue) return true

    // If user has already confirmed in this session, allow submit
    if (this.element.dataset.guestConfirmed === 'true') return true

    event.preventDefault()
    this.showModal()
  }

  showModal() {
    // Simple modal markup appended to body
    const modal = document.createElement('div')
    modal.className = 'guest-token-modal'
    modal.innerHTML = `
      <div class="modal-backdrop"></div>
      <div class="modal-card">
        <h3>You're booking as a guest</h3>
        <p><strong>Note:</strong> Editing or cancelling reservations is available only to registered users. As a guest you'll receive a link to view your reservation, but you will not be able to edit or cancel it unless you create an account and sign in. If you need the ability to modify or cancel, please <a href="/signup">create an account</a> or <a href="/login">sign in</a> before booking.</p>
        <div class="modal-actions">
          <button class="btn btn-secondary modal-close">Close</button>
          <button class="btn btn-primary modal-proceed">Proceed</button>
        </div>
      </div>
    `

    document.body.appendChild(modal)
    this.modalElement = modal

    // Attach direct listeners because the modal is appended outside the controller's
    // element scope, so Stimulus delegated actions won't work. These listeners call
    // the controller methods directly.
    const closeBtn = modal.querySelector('.modal-close')
    const proceedBtn = modal.querySelector('.modal-proceed')
    if (closeBtn) closeBtn.addEventListener('click', this.closeModal.bind(this))
    if (proceedBtn) proceedBtn.addEventListener('click', this.proceed.bind(this))
  }

  closeModal() {
    if (this.modalElement) {
      this.modalElement.remove()
      this.modalElement = null
    }
  }

  proceed() {
    // Mark that the guest confirmed so we don't re-show modal on navigation
    this.element.dataset.guestConfirmed = 'true'
    this.closeModal()

    // Submit the form programmatically in a way that respects modern browsers
    // and Turbo. Prefer requestSubmit (preserves submitter), fallback to click/submit.
    const doSubmit = () => {
      if (typeof this.element.requestSubmit === 'function') {
        this.element.requestSubmit()
        return
      }

      const submitButton = this.element.querySelector('input[type=submit], button[type=submit]')
      if (submitButton) {
        submitButton.click()
      } else if (typeof this.element.submit === 'function') {
        this.element.submit()
      }
    }

    // Small delay to ensure the modal DOM is removed before submitting which avoids
    // visual flicker or leftover backdrop covering the page during navigation.
    // Use a slightly larger delay to be robust across browsers/devtool overlays.
    setTimeout(doSubmit, 150)
  }
}
