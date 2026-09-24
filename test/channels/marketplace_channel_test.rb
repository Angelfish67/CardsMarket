require "test_helper"

class MarketplaceChannelTest < ActionCable::Channel::TestCase
  test "authenticated users share the marketplace stream" do
    stub_connection current_user: users(:one), session_active?: true
    subscribe stream: "someone_else"
    assert subscription.confirmed?
    assert_has_stream MarketplaceChannel::STREAM
    assert_equal 1, subscription.streams.size
  end

  test "invalid sessions cannot subscribe" do
    stub_connection current_user: users(:one), session_active?: false
    subscribe
    assert subscription.rejected?
    assert_no_streams
  end

  test "reconnection removes only offers no longer active" do
    stub_connection current_user: users(:one), session_active?: true
    subscribe
    offer = market_offers(:one)
    missing_id = MarketOffer.maximum(:id) + 1
    perform :synchronize, offer_ids: [ offer.id, missing_id, "invalid", -1 ]
    assert_equal({ "type" => "remove_offers", "offer_ids" => [ missing_id ] }, transmissions.last)

    MarketOfferWithdrawer.call(user: users(:one), offer: offer)
    perform :synchronize, offer_ids: [ offer.id ]
    assert_equal [ offer.id ], transmissions.last["offer_ids"]
  end

  test "expired sessions cannot synchronize or receive events" do
    stub_connection current_user: users(:one), session_active?: true
    subscribe
    handler = nil
    subscription.define_singleton_method(:stream_from) { |*, **, &block| handler = block }
    subscription.subscribed
    connection.define_singleton_method(:session_active?) { false }
    closed = false
    connection.define_singleton_method(:close) { |reconnect:| closed = !reconnect }
    perform :synchronize, offer_ids: [ market_offers(:one).id ]
    handler.call({ "type" => "remove_offer", "offer_id" => market_offers(:one).id })
    assert_empty transmissions
    assert closed
    assert_no_streams
  end
end
