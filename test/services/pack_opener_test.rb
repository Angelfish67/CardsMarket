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
  test "a restricted pack only draws allowed active cards with independent ranks" do
    pack = packs(:beginner)
    pack.update!(allowed_rarities: [ "legendary" ])
    BrainrotType.create!(name: "Inactive legendary", rarity: :legendary, base_value: 100, active: false)
    legendary = BrainrotType.create!(name: "Allowed legendary", rarity: :legendary, base_value: 100)
    e_ticket = Rank.order(:id).take_while { |rank| rank.name != "E" }.sum(&:weight)
    opening = PackOpener.call(user: users(:one), pack: pack, random: ScriptedRandom.new(*([ 0, 0, e_ticket ] * 3)))
    assert_equal [ legendary.id ], opening.brainrot_cards.distinct.pluck(:brainrot_type_id)
    assert opening.brainrot_cards.all? { |card| card.rank.name == "E" }
    assert_equal 900, users(:one).reload.coins
  end

  test "selected tiers keep relative weights and omitted tiers never appear" do
    pack = packs(:beginner)
    pack.update!(allowed_rarities: %w[rare legendary])
    legendary = BrainrotType.create!(name: "Weighted legendary", rarity: :legendary, base_value: 100)
    opening = PackOpener.call(user: users(:one), pack: pack,
      random: ScriptedRandom.new(0, 0, 0, 9, 0, 0, 10, 0, 0))
    assert_equal [ brainrot_types(:two).id, brainrot_types(:two).id, legendary.id ],
      opening.brainrot_cards.order(:id).pluck(:brainrot_type_id)
  end

  test "a stale pack object uses the stored allowed rarities" do
    pack = Pack.find(packs(:beginner).id)
    packs(:beginner).update!(allowed_rarities: [ "rare" ])
    opening = PackOpener.call(user: users(:one), pack: pack)
    assert_equal [ brainrot_types(:two).id ], opening.brainrot_cards.distinct.pluck(:brainrot_type_id)
  end

  test "unavailable allowed tiers never charge coins or consume the starter" do
    pack = packs(:starter)
    pack.update!(allowed_rarities: [ "legendary" ])
    BrainrotType.create!(name: "Disabled legendary", rarity: :legendary, base_value: 100, active: false)
    assert_no_difference [ "PackOpening.count", "BrainrotCard.count" ] do
      assert_raises(GameplayError) { PackOpener.call(user: users(:one), pack: pack) }
    end
    assert_equal 1000, users(:one).reload.coins
    assert_nil users(:one).starter_pack_opened_at
  end
end
