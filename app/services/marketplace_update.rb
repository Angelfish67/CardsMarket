class MarketplaceUpdate
  def self.broadcast_removal(offer)
    # Only public offer IDs belong on this shared stream; wallet data stays
    # on the seller's private SaleNotificationsChannel.
    ActionCable.server.broadcast(MarketplaceChannel::STREAM, {
      type: "remove_offer", offer_id: offer.id
    })
  rescue StandardError => error
    Rails.logger.error("Marketplace update failed for offer #{offer.id}: #{error.class}")
    false
  end
end
