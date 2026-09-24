class SaleNotification
  def self.broadcast(offer)
    seller = offer.user.reload
    SaleNotificationsChannel.broadcast_to(seller, {
      type: "sale",
      offer_id: offer.id,
      seller_id: seller.id,
      card_name: offer.brainrot_card.brainrot_type.name,
      price: offer.price,
      balance: seller.coins,
      wallet_updated_at: seller.updated_at.utc.iso8601(6)
    })
  rescue StandardError => error
    # The sale has already committed. Cable downtime must not turn a successful
    # purchase into an error that might make the buyer try paying again.
    Rails.logger.error("Sale notification failed for offer #{offer.id}: #{error.class}")
    false
  end
end
