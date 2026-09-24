require "test_helper"

class BrainrotCardsControllerTest < ActionDispatch::IntegrationTest
  test "detail page is restricted to its owner including for admins" do
    get brainrot_card_path(brainrot_cards(:one))
    assert_redirected_to new_session_path
    sign_in_as users(:two)
    get brainrot_card_path(brainrot_cards(:one))
    assert_response :not_found
    users(:two).update!(role: :admin)
    sign_in_as users(:two)
    get brainrot_card_path(brainrot_cards(:one))
    assert_response :not_found
    get brainrot_card_path(brainrot_cards(:two))
    assert_response :success
    assert_select "h1", brainrot_types(:two).name
    assert_select ".card-facts", text: /Rare/
  end

  test "rank pull returns to detail and shows the current users history" do
    sign_in_as users(:two)
    card = brainrot_cards(:two)
    assert_difference "RankPull.count", 1 do
      post brainrot_card_rank_pulls_path(card), params: { return_to: "card" }
    end
    assert_redirected_to brainrot_card_path(card)
    follow_redirect!
    assert_response :success
    assert_select ".card-pull-history li", count: 2
    assert_equal 800, users(:two).reload.coins
  end

  test "listed card can be withdrawn on its detail page" do
    sign_in_as users(:one)
    card = brainrot_cards(:one)
    get brainrot_card_path(card)
    assert_select "button[disabled]", "Während des Verkaufs gesperrt"
    delete market_offer_path(market_offers(:one)), params: { return_to: "card" }
    assert_redirected_to brainrot_card_path(card)
    follow_redirect!
    assert_select "form[action=?]", brainrot_card_rank_pulls_path(card)
    assert market_offers(:one).reload.withdrawn?
  end

  test "sale revokes the former owners detail access and prevents rank pulls" do
    sign_in_as users(:one)
    card = brainrot_cards(:one)
    MarketOfferBuyer.call(buyer: users(:two), offer: market_offers(:one))
    get brainrot_card_path(card)
    assert_response :not_found
    assert_no_difference "RankPull.count" do
      post brainrot_card_rank_pulls_path(card), params: { return_to: "card" }
      assert_response :not_found
    end
  end
end
