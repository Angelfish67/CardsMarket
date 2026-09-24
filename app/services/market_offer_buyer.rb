class MarketOfferBuyer
  def self.call(buyer:, offer:)
    seller_id = offer.user_id
    raise GameplayError, "Du kannst dein eigenes Angebot nicht kaufen." if buyer.id == seller_id

    User.transaction do
      # A stable lock order also prevents deadlocks when two traders buy from
      # one another at the same time. Pack/rank actions share these wallet locks.
      wallets = User.where(id: [ buyer.id, seller_id ]).order(:id).lock.to_a
      purchasing_user = wallets.find { |user| user.id == buyer.id }
      seller = wallets.find { |user| user.id == seller_id }
      raise GameplayError, "Dieses Angebot ist nicht mehr verfügbar." unless purchasing_user && seller && !purchasing_user.suspended? && !seller.suspended?

      card = BrainrotCard.lock.find(offer.brainrot_card_id)
      offer.lock!
      unless offer.active? && offer.user_id == seller.id &&
          offer.brainrot_card_id == card.id && card.user_id == seller.id
        raise GameplayError, "Dieses Angebot ist nicht mehr verfügbar."
      end
      raise GameplayError, "Du hast nicht genügend Coins für diese Karte." if purchasing_user.coins < offer.price
      if seller.coins + offer.price > User::MAX_COINS
        raise GameplayError, "Der Verkäufer hat sein Guthabenlimit erreicht. Der Kauf wurde nicht ausgeführt."
      end

      purchasing_user.update!(coins: purchasing_user.coins - offer.price)
      seller.update!(coins: seller.coins + offer.price)
      card.update!(user: purchasing_user)
      offer.update!(status: :sold, buyer: purchasing_user, sold_at: Time.current)
      offer
    end
  end
end
