require "test_helper"

class AuthenticationCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Rails.cache.clear
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
  end

  test "login and registration reject requests without a csrf token" do
    assert_no_difference [ "User.count", "Session.count" ] do
      post session_path, params: { email_address: users(:one).email_address, password: "secure password" }
      assert_response :unprocessable_entity
      post registration_path, params: { user: { username: "csrf", email_address: "csrf@example.com", password: "secure password" } }
      assert_response :unprocessable_entity
    end
  end

  test "valid csrf token permits login and logout requires its own valid token" do
    get new_session_path
    token = css_select("input[name=authenticity_token]").first["value"]
    post session_path, params: { email_address: users(:one).email_address, password: "secure password", authenticity_token: token }
    assert_redirected_to packs_index_path(anchor: "starter-pack")
    assert_no_difference "Session.count" do
      delete session_path
      assert_response :unprocessable_entity
    end
    get root_path
    token = css_select("form[action='#{session_path}'] input[name=authenticity_token]").first["value"]
    assert_difference "Session.count", -1 do
      delete session_path, params: { authenticity_token: token }
    end
    assert_redirected_to new_session_path
  end
end
