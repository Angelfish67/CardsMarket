require "test_helper"

class SaleNotificationsChannelTest < ActionCable::Channel::TestCase
  test "subscribes only to the authenticated seller even if another user is requested" do
    stub_connection current_user: users(:one), session_id: 1, session_active?: true
    subscribe user_id: users(:two).id
    assert subscription.confirmed?
    assert_has_stream_for users(:one)
    assert_equal 1, subscription.streams.size
    assert_not_includes subscription.streams, SaleNotificationsChannel.broadcasting_for(users(:two))
  end

  test "invalid sessions cannot subscribe" do
    stub_connection current_user: users(:one), session_id: 1, session_active?: false
    subscribe
    assert subscription.rejected?
    assert_no_streams
  end

  test "delivery checks that the session is still active" do
    stub_connection current_user: users(:one), session_id: 1, session_active?: true
    subscribe
    handler = nil
    subscription.define_singleton_method(:stream_for) { |*, **, &block| handler = block }
    subscription.subscribed
    handler.call({ "type" => "sale", "price" => 100 })
    assert_equal 1, transmissions.size

    closed = false
    connection.define_singleton_method(:session_active?) { false }
    connection.define_singleton_method(:close) { |reconnect:| closed = !reconnect }
    handler.call({ "type" => "sale", "price" => 200 })
    assert_equal 1, transmissions.size
    assert closed
    assert_no_streams
  end
end
