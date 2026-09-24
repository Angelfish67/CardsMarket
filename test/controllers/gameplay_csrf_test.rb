require "test_helper"

class GameplayCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
  end

  test "pack openings and rank pulls require csrf tokens even when signed in" do
    sign_in_as users(:one)
    assert_no_difference [ "PackOpening.count", "BrainrotCard.count", "RankPull.count" ] do
      post open_pack_path(packs(:starter))
      assert_response :unprocessable_entity
      post brainrot_card_rank_pulls_path(brainrot_cards(:one))
      assert_response :unprocessable_entity
    end
    assert_equal 1000, users(:one).reload.coins
  end

  test "pack button provides a csrf token for opening" do
    sign_in_as users(:one)
    get packs_index_path
    token = css_select("form[action='#{open_pack_path(packs(:starter))}'] input[name=authenticity_token]").first["value"]
    assert_difference "BrainrotCard.count", 3 do
      post open_pack_path(packs(:starter)), params: { authenticity_token: token }
    end
    assert_response :see_other
  end
end
