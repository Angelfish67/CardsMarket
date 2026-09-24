import { Controller } from "@hotwired/stimulus"
import buildConsumer from "channels/consumer"

export default class extends Controller {
  static targets = ["grid", "empty"]

  connect() {
    this.consumer = buildConsumer()
    this.subscription = this.consumer.subscriptions.create("MarketplaceChannel", {
      connected: () => {
        const offerIds = [...this.gridTarget.querySelectorAll("[data-offer-id]")]
          .map((card) => Number(card.dataset.offerId))
        this.subscription.perform("synchronize", { offer_ids: offerIds })
      },
      received: (data) => {
        if (data.type === "remove_offer") this.removeOffer(data.offer_id)
        if (data.type === "remove_offers" && Array.isArray(data.offer_ids)) {
          data.offer_ids.forEach((id) => this.removeOffer(id))
        }
      }
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  removeOffer(id) {
    if (!Number.isSafeInteger(id) || id <= 0) return

    this.gridTarget.querySelector(`[data-offer-id="${id}"]`)?.remove()
    this.dispatch("offer-removed", { detail: { offerId: id } })
    const empty = this.gridTarget.childElementCount === 0
    this.gridTarget.hidden = empty
    this.emptyTarget.hidden = !empty
  }
}
