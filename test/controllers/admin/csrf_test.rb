require "test_helper"

class Admin::CsrfTest < ActionDispatch::IntegrationTest
  setup do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    @protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown { ActionController::Base.allow_forgery_protection = @protection }

  test "privileged mutations require csrf and a valid form token works" do
    assert_no_difference [ "AdminActivity.count", "BrainrotType.count" ] do
      post admin_brainrot_types_path, params: { brainrot_type: { name: "Bad", rarity: "rare", base_value: 1 } }
      assert_response :unprocessable_entity
      patch admin_user_path(users(:two)), params: { user: { role: "admin" } }
      assert_response :unprocessable_entity
      delete admin_market_offer_path(market_offers(:one))
      assert_response :unprocessable_entity
    end
    get edit_admin_pack_path(packs(:one))
    token = css_select("form[action='#{admin_pack_path(packs(:one))}'] input[name=authenticity_token]").first["value"]
    patch admin_pack_path(packs(:one)), params: { authenticity_token: token, pack: { price: 50 } }
    assert_redirected_to admin_packs_path
    assert_equal 50, packs(:one).reload.price
  end
end
