import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "description", "icon", "details", "name", "rarity", "rank",
    "seller", "price", "balance", "remaining", "confirm", "cancel", "errorNote"]
  static values = { userId: Number, balance: Number }

  open(event) {
    if (this.approvedForm === event.target) {
      this.approvedForm = null
      return
    }
    event.preventDefault()
    this.form = event.target
    this.trigger = event.submitter
    this.offerId = Number(this.form.dataset.offerId)
    this.cost = Number(this.form.dataset.price)
    this.titleTarget.textContent = "Kauf bestätigen"
    this.descriptionTarget.textContent = "Prüfe die Details, bevor die Karte in deine Sammlung wechselt."
    this.iconTarget.textContent = "↔"
    this.detailsTarget.hidden = false
    this.errorNoteTarget.hidden = true
    this.confirmTarget.hidden = false
    this.confirmTarget.disabled = false
    this.cancelTarget.textContent = "Abbrechen"
    for (const field of ["name", "rarity", "rank", "seller"]) {
      this[field + "Target"].textContent = this.form.dataset[field]
    }
    this.priceTarget.textContent = this.coins(this.cost)
    this.refreshBalance()
    this.dialogTarget.showModal()
  }

  refreshBalance() {
    const wallet = document.querySelector(`[data-wallet-user="${this.userIdValue}"]`)
    const balance = wallet ? Number(wallet.textContent) : this.balanceValue
    this.balanceTarget.textContent = this.coins(balance)
    this.remainingTarget.textContent = this.coins(balance - this.cost)
    if (balance < this.cost) this.showError("Du hast nicht genügend Coins für diese Karte.")
  }

  walletChanged() {
    if (this.dialogTarget.open && !this.confirmTarget.hidden) this.refreshBalance()
  }

  confirm() {
    if (!this.form?.isConnected) {
      this.showError("Dieses Angebot ist nicht mehr verfügbar. Die Karte wurde möglicherweise bereits gekauft oder das Angebot zurückgezogen.")
      return
    }
    this.refreshBalance()
    if (this.confirmTarget.hidden || this.confirmTarget.disabled) return

    this.confirmTarget.disabled = true
    this.approvedForm = this.form
    this.dialogTarget.close()
    this.form.requestSubmit(this.trigger)
  }

  offerRemoved(event) {
    if (this.dialogTarget.open && event.detail.offerId === this.offerId) {
      this.showError("Dieses Angebot ist nicht mehr verfügbar. Die Karte wurde möglicherweise bereits gekauft oder das Angebot zurückgezogen.")
    }
  }

  showError(message) {
    this.titleTarget.textContent = "Kauf nicht möglich"
    this.descriptionTarget.textContent = message
    this.iconTarget.textContent = "!"
    this.detailsTarget.hidden = true
    this.errorNoteTarget.hidden = false
    this.confirmTarget.hidden = true
    this.cancelTarget.textContent = "Zurück zum Marktplatz"
    if (this.dialogTarget.open) this.cancelTarget.focus()
  }

  cancel() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target !== this.dialogTarget) return
    const rect = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < rect.left || event.clientX > rect.right ||
        event.clientY < rect.top || event.clientY > rect.bottom) this.cancel()
  }

  closed() {
    if (this.trigger?.isConnected) {
      this.trigger.focus()
    } else {
      const heading = document.querySelector("h1")
      heading?.setAttribute("tabindex", "-1")
      heading?.focus()
    }
  }

  beforeCache() {
    this.dialogTarget.close()
    this.approvedForm = null
    this.form = null
  }

  disconnect() {
    this.dialogTarget.close()
  }

  coins(amount) {
    return `${new Intl.NumberFormat("de-DE").format(amount)} Coins`
  }
}
