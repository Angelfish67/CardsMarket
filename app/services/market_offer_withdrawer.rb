class MarketOfferWithdrawer
  def self.call(user:, offer:)
    user.with_lock do
      # Same order as listing, rank pulls and purchases: user -> card -> offer.
      card = BrainrotCard.lock.find(offer.brainrot_card_id)
      offer.lock!
      raise GameplayError, "Du kannst nur eigene Angebote zurückziehen." unless offer.user_id == user.id
      raise GameplayError, "Dieses Angebot ist nicht mehr aktiv." unless offer.active?
      raise GameplayError, "Das Angebot hat sich geändert. Bitte lade die Seite neu." unless offer.brainrot_card_id == card.id

      offer.update!(status: :withdrawn)
      offer
    end
  end
end
