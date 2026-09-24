class WeightedRankDraw
  def self.call(ranks:, random: SecureRandom)
    raise GameplayError, "Aktuell sind keine Ranks verfügbar." if ranks.empty?

    ticket = random.random_number(ranks.sum(&:weight))
    ranks.each do |rank|
      return rank if ticket < rank.weight
      ticket -= rank.weight
    end
  end
end
