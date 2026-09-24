require "test_helper"
require_relative "../test_helpers/scripted_random"

class WeightedBrainrotDrawTest < ActiveSupport::TestCase
  def types
    BrainrotType.rarities.keys.map { |rarity| BrainrotType.new(name: rarity, rarity: rarity, base_value: 100) }
  end

  test "all five rarity tiers follow the specified chances at every boundary" do
    draw = WeightedBrainrotDraw.new(types: types)
    counts = Hash.new(0)
    100.times { |ticket| counts[draw.draw(random: ScriptedRandom.new(ticket, 0)).rarity] += 1 }
    assert_equal({ "common" => 60, "uncommon" => 25, "rare" => 10, "epic" => 4, "legendary" => 1 }, counts)
  end

  test "adding more legendary types does not increase the legendary tier chance" do
    catalog = types + [ BrainrotType.new(name: "Second legendary", rarity: :legendary, base_value: 100) ]
    draw = WeightedBrainrotDraw.new(types: catalog)
    assert_equal "common", draw.draw(random: ScriptedRandom.new(59, 0)).rarity
    assert_equal "epic", draw.draw(random: ScriptedRandom.new(98, 0)).rarity
    assert_equal "legendary", draw.draw(random: ScriptedRandom.new(99, 0)).name
    assert_equal "Second legendary", draw.draw(random: ScriptedRandom.new(99, 1)).name
  end

  test "missing tiers are redistributed and a single available tier always works" do
    catalog = types.select { |type| %w[common legendary].include?(type.rarity) }
    draw = WeightedBrainrotDraw.new(types: catalog)
    assert_equal "common", draw.draw(random: ScriptedRandom.new(59, 0)).rarity
    assert_equal "legendary", draw.draw(random: ScriptedRandom.new(60, 0)).rarity
    chances = WeightedBrainrotDraw.chances(rarities: catalog.map(&:rarity))
    assert_in_delta 100, chances.values.sum, 0.000001
    assert_in_delta 100.0 / 61, chances["legendary"], 0.000001
    assert_equal({ "legendary" => 100.0 }, WeightedBrainrotDraw.chances(rarities: [ "legendary" ]))
    assert_equal({}, WeightedBrainrotDraw.chances(rarities: []))
    assert_raises(GameplayError) { WeightedBrainrotDraw.new(types: []) }
  end

  test "packs apply rarity weights independently from the card rank" do
    legendary = BrainrotType.create!(name: "Golden Brainrot", rarity: :legendary, base_value: 500)
    # Existing fixtures contain Common and Rare: total tier weight 60 + 10 + 1.
    ranks = Rank.order(:id).to_a
    ss_ticket = ranks.take_while { |rank| rank.name != "SS" }.sum(&:weight)
    opening = PackOpener.call(user: users(:one), pack: packs(:starter),
      random: ScriptedRandom.new(*([ 70, 0, ss_ticket ] * 3)))
    assert_equal [ legendary.id ], opening.brainrot_cards.distinct.pluck(:brainrot_type_id)
    assert opening.brainrot_cards.all? { |card| card.rank.name == "SS" && card.value == 2500 }
  end
end
