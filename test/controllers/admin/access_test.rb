require "test_helper"

class Admin::AccessTest < ActionDispatch::IntegrationTest
  test "guests must sign in and traders cannot enter any admin page" do
    paths = [ admin_root_path, admin_brainrot_types_path, new_admin_brainrot_type_path,
      edit_admin_brainrot_type_path(brainrot_types(:one)), admin_packs_path, new_admin_pack_path,
      edit_admin_pack_path(packs(:one)), admin_ranks_path, edit_admin_rank_path(ranks(:one)),
      admin_users_path, edit_admin_user_path(users(:two)), admin_market_offers_path, admin_activities_path ]
    paths.each do |path|
      get path
      assert_redirected_to new_session_path
    end
    sign_in_as users(:one)
    paths.each do |path|
      get path
      assert_response :forbidden
    end
    get root_path
    assert_select "a[href=?]", admin_root_path, count: 0
  end

  test "traders cannot call privileged write endpoints directly" do
    sign_in_as users(:one)
    assert_no_difference [ "AdminActivity.count", "Pack.count", "BrainrotType.count" ] do
      post admin_brainrot_types_path, params: { brainrot_type: { name: "Injected", rarity: "rare", base_value: 1 } }
      assert_response :forbidden
      patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { base_value: 1 } }
      assert_response :forbidden
      patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { active: "false" } }
      assert_response :forbidden
      assert brainrot_types(:one).reload.active?
      post admin_packs_path, params: { pack: { name: "Free", price: 0, cards_count: 99 } }
      assert_response :forbidden
      patch admin_pack_path(packs(:one)), params: { pack: { price: 0 } }
      assert_response :forbidden
      patch admin_rank_path(ranks(:one)), params: { rank: { multiplier: 9999 } }
      assert_response :forbidden
      patch admin_user_path(users(:one)), params: { user: { role: "admin", suspended: false } }
      assert_response :forbidden
      delete admin_market_offer_path(market_offers(:one))
      assert_response :forbidden
    end
    assert users(:one).reload.trader?
    assert market_offers(:one).reload.active?
  end

  test "admin can view all pages and search users" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    [ admin_root_path, admin_brainrot_types_path, new_admin_brainrot_type_path,
      edit_admin_brainrot_type_path(brainrot_types(:one)), admin_packs_path, new_admin_pack_path,
      edit_admin_pack_path(packs(:one)), admin_ranks_path, edit_admin_rank_path(ranks(:one)),
      admin_users_path, edit_admin_user_path(users(:two)), admin_market_offers_path, admin_activities_path ].each do |path|
      get path
      assert_response :success
      assert_equal "no-store", response.headers["Cache-Control"]
    end
    get root_path
    assert_select "a[href=?]", admin_root_path
    get admin_users_path(q: "trader_two")
    assert_select "table", text: /trader_two/
    assert_select "table", text: /trader_one/, count: 0
  end

  test "role is checked again on subsequent requests" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    get admin_root_path
    assert_response :success
    # Simulate a role update while the browser still has its old cookie.
    users(:one).update_columns(role: 0)
    get admin_root_path
    assert_response :forbidden
  end

  test "suspended accounts cannot log in or use old sessions" do
    sign_in_as users(:one)
    users(:one).update_columns(suspended: true)
    get root_path
    assert_redirected_to new_session_path
    assert_no_difference "Session.count" do
      post session_path, params: { email_address: users(:one).email_address, password: "secure password" }
    end
    assert_redirected_to new_session_path
  end
end
