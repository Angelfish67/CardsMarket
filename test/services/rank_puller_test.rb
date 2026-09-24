require "test_helper"
require_relative "../test_helpers/scripted_random"

class RankPullerTest < ActiveSupport::TestCase
  setup { market_offers(:one).withdrawn! }

  test "rank pull charges base value and can upgrade to SS" do
    card = brainrot_cards(:one)
    user = users(:one)
    pull = RankPuller.call(user: user, card: card, random: draw_for(card, ranks(:ss)))
    assert_equal "SS", card.reload.rank.name
    assert_equal 100, pull.coins_spent
    assert_equal 900, user.reload.coins
    assert_equal user, pull.user
    assert_equal card, pull.brainrot_card
  end

  test "same rank still costs coins and price ignores current multiplier" do
    card = brainrot_cards(:two)
    user = users(:two)
    assert_equal 600, card.value
    pull = RankPuller.call(user: user, card: card, random: draw_for(card, ranks(:two)))
    assert_equal "A", card.reload.rank.name
    assert_equal 200, pull.coins_spent
    assert_equal 800, user.reload.coins
  end

  test "lower ranks are excluded from a pull" do
    card = brainrot_cards(:two)
    user = users(:two)
    4.times do |ticket|
      card.update!(rank: ranks(:two))
      RankPuller.call(user: user, card: card, random: ScriptedRandom.new(ticket))
      assert_includes %w[A SS], card.reload.rank.name
    end
  end

  test "foreign listed and max rank cards cannot be pulled" do
    card = brainrot_cards(:one)
    assert_no_difference "RankPull.count" do
      assert_raises(GameplayError) { RankPuller.call(user: users(:two), card: card) }
      market_offers(:one).active!
      assert_raises(GameplayError) { RankPuller.call(user: users(:one), card: card) }
      market_offers(:one).withdrawn!
      card.update!(rank: ranks(:ss))
      assert_raises(GameplayError) { RankPuller.call(user: users(:one), card: card) }
    end
    assert_equal 1000, users(:one).reload.coins
    assert_equal 1000, users(:two).reload.coins
  end

  test "insufficient coins leave rank history and balance unchanged" do
    user = users(:one)
    user.update!(coins: 99)
    assert_no_difference "RankPull.count" do
      assert_raises(GameplayError) { RankPuller.call(user: user, card: brainrot_cards(:one)) }
    end
    assert_equal "E", brainrot_cards(:one).reload.rank.name
    assert_equal 99, user.reload.coins
  end

  test "wallet save failure rolls back changed rank and history" do
    user = users(:one)
    card = brainrot_cards(:one)
    user.define_singleton_method(:update!) { |**attributes| raise "Wallet save failed" }
    assert_no_difference "RankPull.count" do
      assert_raises(RuntimeError) do
        RankPuller.call(user: user, card: card, random: draw_for(card, ranks(:ss)))
      end
    end
    assert_equal "E", card.reload.rank.name
    assert_equal 1000, user.reload.coins
  end

  private

  def draw_for(card, rank)
    eligible = Rank.where(name: Rank::NAMES.drop(Rank::NAMES.index(card.rank.name))).order(:id).to_a
    ticket = eligible.take_while { |candidate| candidate.id != rank.id }.sum(&:weight)
    ScriptedRandom.new(ticket)
  end
end
