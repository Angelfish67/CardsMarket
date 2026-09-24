class WeightedBrainrotDraw
  def initialize(types:)
    @groups = types.group_by(&:rarity)
    @weights = BrainrotType::RARITY_WEIGHTS.select { |rarity, _| @groups.key?(rarity) }
    raise GameplayError, "Aktuell sind keine Karten verfügbar." if @weights.empty?
  end

  def draw(random: SecureRandom)
    ticket = random.random_number(@weights.values.sum)
    @weights.each do |rarity, weight|
      if ticket < weight
        group = @groups.fetch(rarity)
        return group.fetch(random.random_number(group.length))
      end
      ticket -= weight
    end
  end

  def self.chances(rarities:)
    weights = BrainrotType::RARITY_WEIGHTS.slice(*rarities)
    total = weights.values.sum
    weights.transform_values { |weight| weight.fdiv(total) * 100 }
  end
end
