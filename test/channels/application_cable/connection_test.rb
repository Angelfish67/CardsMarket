require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "suspension blocks existing sockets and new connections even with a retained session" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    users(:one).update_columns(suspended: true)
    assert_not connection.session_active?
    assert_reject_connection { connect }
  end

  test "valid signed session authenticates its owner" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    assert_equal users(:one), connection.current_user
    assert_equal session.id, connection.session_id
    assert connection.session_active?
    session.destroy!
    assert_not connection.session_active?
  end

  test "guests and unsigned cookies are rejected" do
    assert_reject_connection { connect }
    cookies[:session_id] = users(:one).sessions.create!.id
    assert_reject_connection { connect }
  end

  test "expired sessions are rejected" do
    session = users(:one).sessions.create!(created_at: 15.days.ago)
    cookies.signed[:session_id] = session.id
    assert_reject_connection { connect }
  end

  test "deleted sessions cannot reconnect" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id
    session.destroy!
    assert_reject_connection { connect }
  end
end
