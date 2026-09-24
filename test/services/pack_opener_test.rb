require "test_helper"
require_relative "../test_helpers/scripted_random"

class PackOpenerTest < ActiveSupport::TestCase
  test "starter grants exactly three independently ranked cards without spending coins" do
    user = users(:one)
    before_coins = user.coins
    opening = nil
    assert_difference "BrainrotCard.count", 3 do
      assert_difference "PackOpening.count", 1 do
        opening = PackOpener.call(user: user, pack: packs(:starter))
      end
    end
    assert opening.starter?
    assert_equal 0, opening.coins_spent
    assert_equal before_coins, user.reload.coins
    assert user.starter_pack_opened_at
    assert_equal [ user.id ], opening.brainrot_cards.distinct.pluck(:user_id)
    assert opening.brainrot_cards.all? { |card| card.rank.present? && card.brainrot_type.present? }
  end

  test "a second starter request is rejected even through another starter pack" do
    user = users(:one)
    PackOpener.call(user: user, pack: packs(:starter))
    other = Pack.create!(name: "Another starter", starter: true, price: 0, cards_count: 3)
    assert_no_difference [ "BrainrotCard.count", "PackOpening.count" ] do
      assert_raises(GameplayError) { PackOpener.call(user: user, pack: other) }
    end
  end

  test "opening history still blocks starter if timestamp was cleared" do
    user = users(:one)
    PackOpener.call(user: user, pack: packs(:starter))
    user.update!(starter_pack_opened_at: nil)
    assert_raises(GameplayError) { PackOpener.call(user: user, pack: packs(:starter)) }
  end

  test "paid pack can be opened repeatedly and charges its stored price" do
    user = users(:one)
    assert_difference "BrainrotCard.count", 6 do
      2.times do
        opening = PackOpener.call(user: user, pack: packs(:beginner))
        assert_equal 100, opening.coins_spent
        assert_not opening.starter?
      end
    end
    assert_equal 800, user.reload.coins
    assert_nil user.starter_pack_opened_at
  end

  test "insufficient coins produce no opening or cards" do
    user = users(:one)
    user.update!(coins: 99)
    assert_no_difference [ "BrainrotCard.count", "PackOpening.count" ] do
      assert_raises(GameplayError) { PackOpener.call(user: user, pack: packs(:beginner)) }
    end
    assert_equal 99, user.reload.coins
  end

  test "failure during third card rolls back the entire starter opening" do
    user = users(:one)
    assert_no_difference [ "BrainrotCard.count", "PackOpening.count" ] do
      assert_raises(RuntimeError) do
        PackOpener.call(user: user, pack: packs(:starter), random: ScriptedRandom.new(0, 0, 0, 0, 0, 0, 0, 0))
      end
    end
    assert_nil user.reload.starter_pack_opened_at
    assert_equal 1000, user.coins
  end

  test "database rejects duplicate starter history without model validation" do
    opening = PackOpener.call(user: users(:one), pack: packs(:starter))
    assert_raises(ActiveRecord::RecordNotUnique) do
      PackOpening.transaction(requires_new: true) { opening.dup.save!(validate: false) }
    end
  end

  test "duplicate character draws are separate owned cards" do
    opening = PackOpener.call(user: users(:one), pack: packs(:starter), random: ScriptedRandom.new(0, 0, 0, 0, 0, 0, 0, 0, 0))
    assert_equal 3, opening.brainrot_cards.count
    assert_equal 1, opening.brainrot_cards.distinct.count(:brainrot_type_id)
    assert_equal 3, opening.brainrot_cards.distinct.count(:id)
  end
end
