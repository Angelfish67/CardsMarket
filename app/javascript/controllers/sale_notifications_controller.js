import { Controller } from "@hotwired/stimulus"
import { subscribeToSales } from "channels/sale_notifications_channel"

export default class extends Controller {
  static values = { userId: Number }

  initialize() {
    this.seen = new Set()
  }

  connect() {
    this.stopSubscription = subscribeToSales((data) => this.received(data))
  }

  disconnect() {
    this.stopSubscription?.()
    this.stopSubscription = null
  }

  received(data) {
    if (data.type !== "sale" || data.seller_id !== this.userIdValue ||
        !Number.isSafeInteger(data.offer_id) || !Number.isSafeInteger(data.price) ||
        typeof data.card_name !== "string" || this.seen.has(data.offer_id)) return

    this.seen.add(data.offer_id)
    this.updateBalance(data)

    const toast = document.createElement("article")
    toast.className = "sale-toast"
    toast.dataset.offerId = data.offer_id

    const icon = document.createElement("span")
    icon.className = "sale-toast-icon"
    icon.setAttribute("aria-hidden", "true")
    icon.textContent = "✦"

    const body = document.createElement("div")
    const title = document.createElement("strong")
    title.textContent = "Karte verkauft!"
    const message = document.createElement("p")
    // Use textContent so a card name can never inject HTML into the page.
    message.textContent = `${data.card_name} wurde für ${data.price} Coins verkauft.`
    body.append(title, message)

    const close = document.createElement("button")
    close.type = "button"
    close.className = "sale-toast-close"
    close.setAttribute("aria-label", "Benachrichtigung schließen")
    close.textContent = "×"
    close.addEventListener("click", () => toast.remove())

    toast.append(icon, body, close)
    this.element.append(toast)
    while (this.element.children.length > 5) this.element.firstElementChild.remove()
  }

  updateBalance(data) {
    if (!Number.isSafeInteger(data.balance) || typeof data.wallet_updated_at !== "string") return

    document.querySelectorAll(`[data-wallet-user="${this.userIdValue}"]`).forEach((element) => {
      // A delayed sale event must not overwrite a more recent wallet state,
      // for example after the seller has opened another pack.
      if ((element.dataset.walletUpdatedAt || "") > data.wallet_updated_at) return
      element.textContent = data.balance
      element.dataset.walletUpdatedAt = data.wallet_updated_at
    })
    window.dispatchEvent(new CustomEvent("wallet:changed"))
  }
}
