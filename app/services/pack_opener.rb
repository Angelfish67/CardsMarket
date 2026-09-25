class PackOpener
  def self.call(user:, pack:, random: SecureRandom)
    # Always lock the wallet first. Concurrent requests then re-read the balance
    # and starter status after the previous request has committed.
    user.with_lock do
      raise GameplayError, "Dieses Konto ist deaktiviert." if user.suspended?
      pack.lock!("FOR SHARE")
      raise GameplayError, "Dieses Pack ist nicht mehr verfügbar." unless pack.active?
      if pack.starter? && (user.starter_pack_opened_at? || user.pack_openings.exists?(starter: true))
        raise GameplayError, "Du hast dein Starter-Pack bereits geöffnet."
      end
      raise GameplayError, "Du hast nicht genügend Coins für dieses Pack." if user.coins < pack.price

      types = pack.available_types.order(:id).lock("FOR KEY SHARE").to_a
      ranks = Rank.order(:id).to_a
      raise GameplayError, "Für die erlaubten Seltenheitsstufen dieses Packs sind aktuell keine Karten verfügbar. Bitte wähle ein anderes Pack." if types.empty?
      raise GameplayError, "Aktuell sind keine Ranks verfügbar." if ranks.empty?

      type_draw = WeightedBrainrotDraw.new(types: types)
      opening = user.pack_openings.create!(pack: pack, coins_spent: pack.price, starter: pack.starter?)
      # The starter pack always grants exactly three independent draws.
      count = pack.starter? ? 3 : pack.cards_count
      count.times do
        opening.brainrot_cards.create!(
          user: user,
          brainrot_type: type_draw.draw(random: random),
          rank: WeightedRankDraw.call(ranks: ranks, random: random)
        )
      end
      user.coins -= pack.price
      user.starter_pack_opened_at = Time.current if pack.starter?
      user.save!
      opening
    end
  end
end
