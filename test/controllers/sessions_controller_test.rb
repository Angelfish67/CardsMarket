require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "login form is public" do
    get new_session_path
    assert_response :success
  end

  test "login normalizes email and creates a protected cookie" do
    assert_difference "Session.count", 1 do
      post session_path, params: { email_address: " ONE@EXAMPLE.COM ", password: "secure password" }
    end
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    cookie = response.headers["Set-Cookie"].to_s
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)
    follow_redirect!
    assert_response :success
    assert_select "#starter-pack"
  end

  test "wrong password and unknown email produce the same response" do
    messages = [ @user.email_address, "unknown@example.com" ].map do |email|
      assert_no_difference "Session.count" do
        post session_path, params: { email_address: email, password: "wrong password" }
      end
      assert_redirected_to new_session_path
      flash[:alert]
    end
    assert_equal messages.first, messages.last
  end

  test "missing credentials fail gracefully" do
    [ {}, { email_address: @user.email_address }, { password: "secure password" } ].each do |credentials|
      post session_path, params: credentials
      assert_redirected_to new_session_path
    end
  end

  test "login returns to the originally requested protected page" do
    get inventory_index_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to inventory_index_path
  end

  test "logout revokes only the current session and replay no longer authenticates" do
    other_session = @user.sessions.create!
    sign_in_as @user
    old_cookie = cookies[:session_id]
    assert_difference "Session.count", -1 do
      delete session_path
    end
    assert_redirected_to new_session_path
    assert Session.exists?(other_session.id)
    cookies[:session_id] = old_cookie
    get root_path
    assert_redirected_to new_session_path
  end

  test "expired and tampered cookies cannot access dashboard" do
    sign_in_as @user
    @user.sessions.last.update!(created_at: 15.days.ago)
    get root_path
    assert_redirected_to new_session_path
    cookies[:session_id] = "tampered"
    get root_path
    assert_redirected_to new_session_path
  end

  test "a new login revokes the previous browser session" do
    sign_in_as @user
    previous = @user.sessions.last
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    assert_not Session.exists?(previous.id)
  end

  test "https login marks the cookie secure" do
    https!
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    assert_match(/; secure/i, response.headers["Set-Cookie"].to_s)
  end

  test "head requests preserve a safe return path" do
    head inventory_index_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to inventory_index_path
  end

  test "login is rate limited" do
    10.times do
      post session_path, params: { email_address: @user.email_address, password: "wrong password" }
    end
    assert_no_difference "Session.count" do
      post session_path, params: { email_address: @user.email_address, password: "secure password" }
    end
    assert_redirected_to new_session_path
    assert_equal "Bitte versuche es später erneut.", flash[:alert]
  end
end
