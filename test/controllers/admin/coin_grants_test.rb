require "test_helper"

class Admin::CoinGrantsTest < ActionDispatch::IntegrationTest
  test "guests and traders cannot give themselves coins" do
    user = users(:two)
    post credit_coins_admin_user_path(user), params: { credit: { amount: 100 } }
    assert_redirected_to new_session_path
    sign_in_as user
    assert_no_difference "AdminActivity.count" do
      post credit_coins_admin_user_path(user), params: { credit: { amount: 100 } }
      assert_response :forbidden
    end
    assert_equal 1000, user.reload.coins
  end

  test "admin grants coins from the user page without accepting role changes" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    user = users(:two)
    get admin_users_path
    assert_select "a[href=?]", edit_admin_user_path(user, anchor: "coins"), text: "Coins vergeben"
    get edit_admin_user_path(user)
    assert_select "form[action=?]", credit_coins_admin_user_path(user) do
      assert_select "input[name='credit[amount]'][min='1'][step='1']"
    end
    assert_difference "AdminActivity.count", 1 do
      post credit_coins_admin_user_path(user), params: { credit: { amount: 500, reason: "Bonus", role: "admin", coins: 999999 } }
    end
    assert_redirected_to edit_admin_user_path(user, anchor: "coins")
    assert_equal 1500, user.reload.coins
    assert user.trader?
    follow_redirect!
    assert_select "#coins", text: /1,500 Coins/
    get admin_activities_path
    assert_select "td", text: "Coins gutgeschrieben"
  end

  test "invalid grants show errors and keep the entered values" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    assert_no_difference "AdminActivity.count" do
      post credit_coins_admin_user_path(users(:two)), params: { credit: { amount: "-3", reason: "Bonus" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /positiven Betrag/
    assert_select "input[name='credit[reason]'][value='Bonus']"
    assert_equal 1000, users(:two).reload.coins
  end

  test "grant requires a valid csrf token" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post credit_coins_admin_user_path(users(:two)), params: { credit: { amount: 50 } }
    assert_response :unprocessable_entity
    assert_equal 1000, users(:two).reload.coins
    get edit_admin_user_path(users(:two))
    token = css_select("form[action='#{credit_coins_admin_user_path(users(:two))}'] input[name=authenticity_token]").first["value"]
    post credit_coins_admin_user_path(users(:two)), params: { credit: { amount: 50 }, authenticity_token: token }
    assert_redirected_to edit_admin_user_path(users(:two), anchor: "coins")
    assert_equal 1050, users(:two).reload.coins
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
