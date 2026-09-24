require "test_helper"

class MarketplaceUpdateTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  self.use_transactional_tests = false

  test "committed purchase sends only the public offer id once" do
    offer = market_offers(:one)
    messages = capture_broadcasts(MarketplaceChannel::STREAM) do
      MarketOfferBuyer.call(buyer: users(:two), offer: offer)
    end
    assert_equal [ { "type" => "remove_offer", "offer_id" => offer.id } ], messages

    assert_no_broadcasts MarketplaceChannel::STREAM do
      offer.update!(sold_at: 1.minute.ago)
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: offer) }
    end
  end

  test "withdrawn offers also disappear" do
    offer = market_offers(:one)
    assert_broadcast_on(MarketplaceChannel::STREAM, type: "remove_offer", offer_id: offer.id) do
      MarketOfferWithdrawer.call(user: users(:one), offer: offer)
    end
  end

  test "rollback and failed purchase do not remove offers" do
    offer = market_offers(:one)
    assert_no_broadcasts MarketplaceChannel::STREAM do
      User.transaction do
        MarketOfferBuyer.call(buyer: users(:two), offer: offer)
        raise ActiveRecord::Rollback
      end
      users(:two).update!(coins: 0)
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: offer.reload) }
    end
    assert offer.reload.active?
  end

  test "broadcast failure does not report a completed purchase as failed" do
    original = ActionCable.server.method(:broadcast)
    ActionCable.server.define_singleton_method(:broadcast) { |*| raise IOError, "Cable unavailable" }
    offer = MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one))
    assert offer.reload.sold?
    assert_equal 1100, users(:one).reload.coins
    assert_equal 900, users(:two).reload.coins
  ensure
    ActionCable.server.define_singleton_method(:broadcast, original)
  end
end
