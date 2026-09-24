require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "all account endpoints require login" do
    get edit_account_path
    assert_redirected_to new_session_path
    patch account_path, params: { account: { username: "hacker" } }
    assert_redirected_to new_session_path
    patch password_account_path, params: { account: { password: "hacker password" } }
    assert_redirected_to new_session_path
    post deactivate_account_path, params: { account: { confirmation: "1" } }
    assert_redirected_to new_session_path
    assert_equal "trader_one", @user.reload.username
    assert_not @user.suspended?
  end

  test "settings show separate forms and no cached secrets" do
    sign_in_as @user
    get edit_account_path
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "a[href=?]", edit_account_path, text: "Mein Konto"
    [ account_path, password_account_path, deactivate_account_path ].each do |path|
      assert_select "form[action=?]", path
    end
    assert_select "input[type=password][value]", count: 0
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids
  end

  test "profile updates normalize names and ignore foreign ids roles balances and passwords" do
    sign_in_as @user
    session_ids = @user.sessions.ids
    patch account_path, params: { id: users(:two).id, account: {
      current_password: "secure password", username: "  New_Name  ", email_address: " ONE@EXAMPLE.COM ",
      id: users(:two).id, role: "admin", suspended: true, coins: 999999, password: "injected password"
    } }
    assert_redirected_to edit_account_path
    assert_equal "new_name", @user.reload.username
    assert_equal "one@example.com", @user.email_address
    assert @user.trader?
    assert_not @user.suspended?
    assert_equal 1000, @user.coins
    assert @user.authenticate("secure password")
    assert_equal session_ids, @user.sessions.ids
    assert_equal "trader_two", users(:two).reload.username
  end

  test "wrong current password and conflicting profile fields leave account unchanged" do
    sign_in_as @user
    patch account_path, params: { account: { current_password: "wrong", username: "changed" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /aktuelle Passwort/
    assert_equal "trader_one", @user.reload.username
    patch account_path, params: { account: { current_password: "secure password",
      username: " TRADER_TWO ", email_address: " TWO@EXAMPLE.COM " } }
    assert_response :unprocessable_entity
    assert_equal "trader_one", @user.reload.username
    assert_equal "one@example.com", @user.email_address
    assert_select "input[type=password][value]", count: 0
  end

  test "email changes invalidate all sessions and require the new login address" do
    sign_in_as @user
    old_cookie = cookies[:session_id]
    @user.sessions.create!
    patch account_path, params: { account: { current_password: "secure password", email_address: " NEW@EXAMPLE.COM " } }
    assert_redirected_to new_session_path
    assert_equal "new@example.com", @user.reload.email_address
    assert_empty @user.sessions.reload
    cookies[:session_id] = old_cookie
    get edit_account_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: "one@example.com", password: "secure password" }
    assert_redirected_to new_session_path
    post session_path, params: { email_address: "new@example.com", password: "secure password" }
    assert_redirected_to edit_account_path
  end

  test "password change hashes the new password logs out all devices and rejects old cookies and password" do
    sign_in_as @user
    old_cookie = cookies[:session_id]
    @user.sessions.create!
    patch password_account_path, params: { account: { current_password: "secure password",
      password: "my new secure password", password_confirmation: "my new secure password" } }
    assert_redirected_to new_session_path
    assert_empty @user.sessions.reload
    assert @user.reload.authenticate("my new secure password")
    assert_not @user.authenticate("secure password")
    assert_not_equal "my new secure password", @user.password_digest
    cookies[:session_id] = old_cookie
    get edit_account_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to new_session_path
    post session_path, params: { email_address: @user.email_address, password: "my new secure password" }
    assert_redirected_to edit_account_path
  end

  test "invalid new passwords never change the digest or sessions" do
    sign_in_as @user
    digest = @user.password_digest
    sessions = @user.sessions.ids
    [ [ "", "" ], [ "short", "short" ], [ "a" * 73, "a" * 73 ], [ "ü" * 37, "ü" * 37 ],
      [ "a secure new password", "" ], [ "a secure new password", "does not match" ] ].each do |password, confirmation|
      patch password_account_path, params: { account: { current_password: "secure password",
        password: password, password_confirmation: confirmation } }
      assert_response :unprocessable_entity
      assert_equal digest, @user.reload.password_digest
      assert_equal sessions, @user.sessions.ids
      assert_select "input[type=password][value]", count: 0
    end
  end

  test "deactivation requires current password and explicit confirmation" do
    sign_in_as @user
    [ { current_password: "wrong", confirmation: "1" }, { current_password: "secure password", confirmation: "0" } ].each do |input|
      post deactivate_account_path, params: { account: input }
      assert_response :unprocessable_entity
      assert_not @user.reload.suspended?
      assert market_offers(:one).reload.active?
    end
  end

  test "deactivation withdraws offers preserves assets and revokes every session" do
    sign_in_as @user
    old_cookie = cookies[:session_id]
    @user.sessions.create!
    card_ids = @user.brainrot_cards.ids
    post deactivate_account_path, params: { account: { current_password: "secure password", confirmation: "1" } }
    assert_redirected_to new_session_path
    assert @user.reload.suspended?
    assert_empty @user.sessions.reload
    assert_equal 1000, @user.coins
    assert_equal card_ids, @user.brainrot_cards.ids
    assert market_offers(:one).reload.withdrawn?
    cookies[:session_id] = old_cookie
    get root_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_redirected_to new_session_path
    assert_empty @user.sessions.reload
  end

  test "the last admin cannot deactivate but another admin can reactivate an account" do
    @user.update!(role: :admin)
    sign_in_as @user
    post deactivate_account_path, params: { account: { current_password: "secure password", confirmation: "1" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /aktiver Admin/
    assert_not @user.reload.suspended?
    assert market_offers(:one).reload.active?
    users(:two).update!(role: :admin)
    post deactivate_account_path, params: { account: { current_password: "secure password", confirmation: "1" } }
    assert_redirected_to new_session_path
    assert @user.reload.suspended?
    Admin::UserUpdater.call(actor: users(:two), user: @user, attributes: { suspended: false })
    post session_path, params: { email_address: @user.email_address, password: "secure password" }
    assert_response :redirect
    assert_not_equal new_session_url, response.location
    assert market_offers(:one).reload.withdrawn?
  end

  test "account changes require csrf tokens" do
    sign_in_as @user
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    patch account_path, params: { account: { current_password: "secure password", username: "changed" } }
    assert_response :unprocessable_entity
    patch password_account_path, params: { account: { current_password: "secure password", password: "new secure password" } }
    assert_response :unprocessable_entity
    post deactivate_account_path, params: { account: { current_password: "secure password", confirmation: "1" } }
    assert_response :unprocessable_entity
    assert_equal "trader_one", @user.reload.username
    assert_not @user.suspended?
    get edit_account_path
    token = css_select("form[action='#{account_path}'] input[name=authenticity_token]").first["value"]
    patch account_path, params: { authenticity_token: token, account: { current_password: "secure password", username: "changed" } }
    assert_redirected_to edit_account_path
    assert_equal "changed", @user.reload.username
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "password checks are rate limited" do
    sign_in_as @user
    10.times { patch account_path, params: { account: { current_password: "wrong", username: "changed" } } }
    patch account_path, params: { account: { current_password: "secure password", username: "changed" } }
    assert_redirected_to edit_account_path
    assert_equal "Bitte versuche es später erneut.", flash[:alert]
    assert_equal "trader_one", @user.reload.username
  end
end
