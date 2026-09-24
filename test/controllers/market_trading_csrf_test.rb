require "test_helper"

class MarketTradingCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown { ActionController::Base.allow_forgery_protection = @previous_protection }

  test "listing withdrawal and purchase all require csrf tokens" do
    sign_in_as users(:two)
    assert_no_difference "MarketOffer.count" do
      post brainrot_card_market_offers_path(brainrot_cards(:two)), params: { market_offer: { price: 100 } }
      assert_response :unprocessable_entity
      post purchase_market_offer_path(market_offers(:one))
      assert_response :unprocessable_entity
    end
    sign_in_as users(:one)
    delete market_offer_path(market_offers(:one))
    assert_response :unprocessable_entity
    assert market_offers(:one).reload.active?
    assert_equal 1000, users(:one).reload.coins
    assert_equal 1000, users(:two).reload.coins
  end

  test "sale and purchase forms submit successfully with their csrf tokens" do
    sign_in_as users(:two)
    get new_brainrot_card_market_offer_path(brainrot_cards(:two))
    token = css_select("form[action='#{brainrot_card_market_offers_path(brainrot_cards(:two))}'] input[name=authenticity_token]").first["value"]
    post brainrot_card_market_offers_path(brainrot_cards(:two)), params: { market_offer: { price: 150 }, authenticity_token: token }
    assert_redirected_to marketplace_index_path
    get marketplace_index_path
    token = css_select("form[action='#{purchase_market_offer_path(market_offers(:one))}'] input[name=authenticity_token]").first["value"]
    post purchase_market_offer_path(market_offers(:one)), params: { authenticity_token: token }
    assert_redirected_to inventory_index_path
    assert market_offers(:one).reload.sold?
  end
end
