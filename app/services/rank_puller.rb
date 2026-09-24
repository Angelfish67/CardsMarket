class RankPuller
  def self.call(user:, card:, random: SecureRandom)
    user.with_lock do
      card.with_lock do
        raise GameplayError, "Diese Karte gehört dir nicht." unless card.user_id == user.id
        raise GameplayError, "Ziehe zuerst das Verkaufsangebot für diese Karte zurück." if card.market_offers.active.exists?

        current_rank = card.rank.reload
        position = Rank::NAMES.index(current_rank.name)
        raise GameplayError, "Diese Karte hat bereits den höchsten Rank SS." if current_rank.name == "SS"

        # Condition the existing weights on ranks at least as good as the current
        # one. A pull can keep the same rank, but can never downgrade a card.
        ranks = Rank.where(name: Rank::NAMES.drop(position)).order(:id).to_a
        unless ranks.any? { |rank| Rank::NAMES.index(rank.name) > position }
          raise GameplayError, "Aktuell ist kein höherer Rank verfügbar."
        end

        cost = card.brainrot_type.reload.base_value
        raise GameplayError, "Du hast nicht genügend Coins für diesen Rank-Pull." if user.coins < cost

        rank = WeightedRankDraw.call(ranks: ranks, random: random)
        pull = card.rank_pulls.create!(user: user, rank: rank, coins_spent: cost)
        card.update!(rank: rank)
        user.update!(coins: user.coins - cost)
        pull
      end
    end
  end
end
