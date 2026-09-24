require "test_helper"

class SaleNotificationTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  self.use_transactional_tests = false

  test "completed sale broadcasts once and only to its seller" do
    offer = market_offers(:one)
    seller_stream = SaleNotificationsChannel.broadcasting_for(users(:one))
    buyer_stream = SaleNotificationsChannel.broadcasting_for(users(:two))
    messages = capture_broadcasts(seller_stream) do
      assert_no_broadcasts buyer_stream do
        MarketOfferBuyer.call(buyer: users(:two), offer: offer)
      end
    end
    assert_equal 1, messages.size
    assert_equal "sale", messages.first["type"]
    assert_equal offer.id, messages.first["offer_id"]
    assert_equal users(:one).id, messages.first["seller_id"]
    assert_equal brainrot_types(:one).name, messages.first["card_name"]
    assert_equal 100, messages.first["price"]
    assert_equal 1100, messages.first["balance"]

    assert_no_broadcasts seller_stream do
      offer.update!(sold_at: 1.minute.ago)
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: offer) }
    end
  end

  test "outer transaction rollback sends no sale notification" do
    offer = market_offers(:one)
    stream = SaleNotificationsChannel.broadcasting_for(users(:one))
    assert_no_broadcasts stream do
      User.transaction do
        MarketOfferBuyer.call(buyer: users(:two), offer: offer)
        assert offer.reload.sold?
        raise ActiveRecord::Rollback
      end
    end
    assert offer.reload.active?
    assert_equal 1000, users(:one).reload.coins
    assert_equal 1000, users(:two).reload.coins
  end

  test "failed purchase and withdrawal send no sale notifications" do
    stream = SaleNotificationsChannel.broadcasting_for(users(:one))
    users(:two).update!(coins: 0)
    assert_no_broadcasts stream do
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one)) }
      MarketOfferWithdrawer.call(user: users(:one), offer: market_offers(:one))
    end
  end

  test "cable failure does not roll back or report failure for a completed purchase" do
    original = SaleNotificationsChannel.method(:broadcast_to)
    SaleNotificationsChannel.define_singleton_method(:broadcast_to) { |*| raise IOError, "Cable unavailable" }
    offer = MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one))
    assert offer.reload.sold?
    assert_equal 1100, users(:one).reload.coins
    assert_equal 900, users(:two).reload.coins
  ensure
    SaleNotificationsChannel.define_singleton_method(:broadcast_to, original)
  end

  test "destroying a session disconnects only that sessions sockets without reconnecting" do
    user = users(:one)
    session = user.sessions.create!
    other_session = user.sessions.create!
    remote = ActionCable.server.remote_connections.where(current_user: user, session_id: session.id)
    other_remote = ActionCable.server.remote_connections.where(current_user: user, session_id: other_session.id)
    assert_no_broadcasts other_remote.send(:internal_channel) do
      assert_broadcast_on(remote.send(:internal_channel), type: "disconnect", reconnect: false) { session.destroy! }
    end
    assert Session.exists?(other_session.id)
  end
end
