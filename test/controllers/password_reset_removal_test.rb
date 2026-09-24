require "test_helper"

class PasswordResetRemovalTest < ActionDispatch::IntegrationTest
  test "login has no password reset link and still accepts credentials" do
    get new_session_path
    assert_response :success
    assert_select "a[href*='/passwords']", count: 0
    assert_select "input[name=password]"
    assert_select "input[name=email_address]"
  end

  test "old reset endpoints are unavailable and cannot change passwords" do
    user = users(:one)
    assert_no_changes -> { user.reload.password_digest } do
      get "/passwords/new"
      assert_response :not_found
      get "/passwords/old-token/edit"
      assert_response :not_found
      assert_no_enqueued_jobs do
        post "/passwords", params: { email_address: user.email_address }
        assert_response :not_found
      end
      patch "/passwords/old-token", params: { password: "replacement password" }
      assert_response :not_found
      put "/passwords/old-token", params: { password: "replacement password" }
      assert_response :not_found
    end
  end

  test "users no longer generate password reset tokens" do
    assert_not users(:one).respond_to?(:password_reset_token)
    assert_not User.respond_to?(:find_by_password_reset_token)
  end
end
