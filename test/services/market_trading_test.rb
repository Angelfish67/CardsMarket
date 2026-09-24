require "test_helper"

class MarketTradingTest < ActiveSupport::TestCase
  test "listing sets server controlled seller and keeps card and coins" do
    user = users(:two)
    card = brainrot_cards(:two)
    offer = MarketOfferCreator.call(user: user, card: card, price: "350")
    assert_equal 350, offer.price
    assert offer.active?
    assert_equal user, offer.user
    assert_nil offer.buyer
    assert_equal user, card.reload.user
    assert_equal 1000, user.reload.coins
  end

  test "foreign and already listed cards cannot be offered" do
    assert_no_difference "MarketOffer.count" do
      assert_raises(GameplayError) { MarketOfferCreator.call(user: users(:one), card: brainrot_cards(:two), price: 100) }
      assert_raises(GameplayError) { MarketOfferCreator.call(user: users(:one), card: brainrot_cards(:one), price: 100) }
    end
  end

  test "prices must be positive whole coins within storage limits" do
    [ nil, "", "0", "-5", "1.5", "abc", "2147483648" ].each do |price|
      assert_no_difference "MarketOffer.count" do
        assert_raises(ActiveRecord::RecordInvalid) do
          MarketOfferCreator.call(user: users(:two), card: brainrot_cards(:two), price: price)
        end
      end
    end
  end

  test "withdrawal keeps history and permits relisting and rank pulls" do
    offer = market_offers(:one)
    assert_raises(GameplayError) { RankPuller.call(user: users(:one), card: brainrot_cards(:one)) }
    assert_no_difference "MarketOffer.count" do
      MarketOfferWithdrawer.call(user: users(:one), offer: offer)
    end
    assert offer.reload.withdrawn?
    assert_equal users(:one), offer.brainrot_card.user
    assert_equal 1000, users(:one).reload.coins
    RankPuller.call(user: users(:one), card: brainrot_cards(:one))
    new_offer = MarketOfferCreator.call(user: users(:one), card: brainrot_cards(:one), price: 200)
    assert new_offer.active?
    assert_not_equal offer.id, new_offer.id
  end

  test "foreign and inactive offers cannot be withdrawn" do
    assert_raises(GameplayError) { MarketOfferWithdrawer.call(user: users(:two), offer: market_offers(:one)) }
    assert_raises(GameplayError) { MarketOfferWithdrawer.call(user: users(:two), offer: market_offers(:two)) }
    assert market_offers(:one).reload.active?
  end

  test "purchase transfers exactly the price and ownership and preserves origin" do
    offer = market_offers(:one)
    origin = offer.brainrot_card.pack_opening
    assert_no_difference [ "BrainrotCard.count", "MarketOffer.count", "User.sum(:coins)" ] do
      MarketOfferBuyer.call(buyer: users(:two), offer: offer)
    end
    assert offer.reload.sold?
    assert_equal users(:two), offer.buyer
    assert offer.sold_at
    assert_equal users(:one), offer.user
    assert_equal users(:two), offer.brainrot_card.reload.user
    assert_equal origin, offer.brainrot_card.pack_opening
    assert_equal 900, users(:two).reload.coins
    assert_equal 1100, users(:one).reload.coins
    assert MarketOfferCreator.call(user: users(:two), card: offer.brainrot_card, price: 150).active?
  end

  test "own withdrawn and sold offers cannot be bought" do
    assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:one), offer: market_offers(:one)) }
    assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:one), offer: market_offers(:two)) }
    MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one))
    assert_no_changes -> { users(:two).reload.coins } do
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one)) }
    end
  end

  test "insufficient coins leave seller buyer card and offer unchanged" do
    users(:two).update!(coins: 99)
    assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one)) }
    assert_equal 99, users(:two).reload.coins
    assert_equal 1000, users(:one).reload.coins
    assert_equal users(:one), brainrot_cards(:one).reload.user
    assert market_offers(:one).reload.active?
  end

  test "failure after coin and card updates rolls back the whole sale" do
    offer = market_offers(:one)
    offer.define_singleton_method(:update!) { |**attributes| raise "Sale save failed" }
    assert_raises(RuntimeError) { MarketOfferBuyer.call(buyer: users(:two), offer: offer) }
    assert_equal 1000, users(:two).reload.coins
    assert_equal 1000, users(:one).reload.coins
    assert_equal users(:one), brainrot_cards(:one).reload.user
    assert offer.reload.active?
    assert_nil offer.buyer
    assert_nil offer.sold_at
  end

  test "seller balance overflow is rejected without taking buyer coins" do
    users(:one).update!(coins: User::MAX_COINS)
    assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one)) }
    assert_equal 1000, users(:two).reload.coins
    assert market_offers(:one).reload.active?
  end
end
