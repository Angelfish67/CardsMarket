class MarketOfferCreator
  def self.call(user:, card:, price:)
    user.with_lock do
      card.with_lock do
        raise GameplayError, "Du kannst nur eigene Karten anbieten." unless card.user_id == user.id
        raise GameplayError, "Diese Karte wird bereits angeboten." if card.market_offers.active.exists?

        card.market_offers.create!(user: user, price: price, status: :active)
      end
    end
  end
end
