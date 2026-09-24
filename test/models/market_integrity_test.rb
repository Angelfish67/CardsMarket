require "test_helper"

class MarketIntegrityTest < ActiveSupport::TestCase
  test "new users receive the same coins and trader role" do
    user = User.create!(username: " New_Trader ", email_address: " NEW@example.com ", password: "secure password")
    assert_equal 1_000, user.coins
    assert user.trader?
    assert_equal "new_trader", user.username
    assert_equal "new@example.com", user.email_address
  end

  test "user identity is unique and coins cannot be negative" do
    user = User.new(username: " TRADER_ONE ", email_address: " ONE@example.com ", password: "secure password", coins: -1)
    assert_not user.valid?
    assert user.errors.added?(:username, :taken, value: "trader_one")
    assert user.errors[:email_address].any?
    assert user.errors[:coins].any?
  end

  test "invalid enums and missing required associations are rejected" do
    assert_not User.new(role: :unknown).valid?
    assert_not BrainrotType.new(name: "Invalid", rarity: :unknown, base_value: 1).valid?
    assert_not MarketOffer.new(status: :unknown).valid?
    [ BrainrotCard.new, PackOpening.new, RankPull.new ].each do |record|
      assert_not record.valid?
      assert record.errors[:user].any?
    end
  end

  test "catalogue and pack values must be valid" do
    assert_not Rank.new(name: "S", multiplier: 0, weight: -1).valid?
    assert_not BrainrotType.new(name: "", rarity: :common, base_value: 0).valid?
    assert_not Pack.new(name: "Starter", price: 10, cards_count: 3, starter: true).valid?
    assert_not Pack.new(name: "Empty", price: 0, cards_count: 0, starter: false).valid?
    assert_not PackOpening.new(user: users(:one), pack: packs(:one), coins_spent: -1).valid?
    assert_not RankPull.new(user: users(:one), brainrot_card: brainrot_cards(:one), rank: ranks(:one), coins_spent: -1).valid?
  end

  test "only the owner can offer a card or request a rank pull" do
    offer = MarketOffer.new(user: users(:one), brainrot_card: brainrot_cards(:two), price: 10)
    assert_not offer.valid?
    assert offer.errors[:brainrot_card].any?
    pull = RankPull.new(user: users(:one), brainrot_card: brainrot_cards(:two), rank: ranks(:one), coins_spent: 10)
    assert_not pull.valid?
    assert pull.errors[:brainrot_card].any?
  end

  test "only one active offer per card and withdrawn cards can be relisted" do
    duplicate = MarketOffer.new(user: users(:one), brainrot_card: brainrot_cards(:one), price: 10)
    assert_not duplicate.valid?
    market_offers(:one).withdrawn!
    assert duplicate.save
  end

  test "sold offers require a different buyer and timestamp" do
    offer = market_offers(:one)
    offer.status = :sold
    assert_not offer.valid?
    offer.buyer = users(:one)
    offer.sold_at = Time.current
    assert_not offer.valid?
    offer.buyer = users(:two)
    assert offer.valid?
    offer.status = :active
    assert_not offer.valid?
  end

  test "ownership changes preserve pack origin and historical seller" do
    card = brainrot_cards(:one)
    offer = market_offers(:one)
    offer.update!(status: :sold, buyer: users(:two), sold_at: Time.current)
    card.update!(user: users(:two))
    assert_equal users(:one), card.pack_opening.user
    assert_equal users(:one), offer.user
    assert_equal card, users(:two).brainrot_cards.find(card.id)
    assert_equal offer, users(:two).purchases.find(offer.id)
    assert MarketOffer.create!(user: users(:two), brainrot_card: card, price: 150)
  end

  test "card value uses its type and rank multiplier" do
    assert_equal 600, brainrot_cards(:two).value
  end

  test "referenced records cannot be destroyed" do
    [ users(:one), brainrot_types(:one), ranks(:one), packs(:one), pack_openings(:one), brainrot_cards(:one) ].each do |record|
      assert_not record.destroy
      assert record.errors[:base].any?
    end
  end

  test "database prevents duplicate active offers even without validations" do
    offer = market_offers(:one).dup
    assert_raises(ActiveRecord::RecordNotUnique) do
      MarketOffer.transaction(requires_new: true) { offer.save!(validate: false) }
    end
  end

  test "database rejects negative coins even without validations" do
    assert_raises(ActiveRecord::StatementInvalid) do
      User.transaction(requires_new: true) { users(:one).update_columns(coins: -1) }
    end
  end
end
