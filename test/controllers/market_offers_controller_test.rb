require "test_helper"

class MarketOffersControllerTest < ActionDispatch::IntegrationTest
  test "guests cannot list withdraw or purchase" do
    assert_no_difference "MarketOffer.count" do
      get new_brainrot_card_market_offer_path(brainrot_cards(:two))
      assert_redirected_to new_session_path
      post brainrot_card_market_offers_path(brainrot_cards(:two)), params: { market_offer: { price: 100 } }
      assert_redirected_to new_session_path
      delete market_offer_path(market_offers(:one))
      assert_redirected_to new_session_path
      post purchase_market_offer_path(market_offers(:one))
      assert_redirected_to new_session_path
    end
    assert market_offers(:one).reload.active?
  end

  test "selling from inventory creates an offer without accepting privileged attributes" do
    sign_in_as users(:two)
    get inventory_index_path
    assert_select "a[href=?]", new_brainrot_card_market_offer_path(brainrot_cards(:two))
    get new_brainrot_card_market_offer_path(brainrot_cards(:two))
    assert_response :success
    assert_select "input[name='market_offer[price]'][min='1']"
    assert_difference "MarketOffer.count", 1 do
      post brainrot_card_market_offers_path(brainrot_cards(:two)), params: {
        market_offer: { price: 350, user_id: users(:one).id, buyer_id: users(:one).id, status: "sold", brainrot_card_id: brainrot_cards(:one).id }
      }
    end
    assert_redirected_to marketplace_index_path
    offer = brainrot_cards(:two).market_offers.active.sole
    assert_equal 350, offer.price
    assert_equal users(:two), offer.user
    assert_nil offer.buyer_id
    follow_redirect!
    assert_select "article#market_offer_#{offer.id} form[action=?]", market_offer_path(offer)
    assert_select "article#market_offer_#{offer.id} form[action=?]", purchase_market_offer_path(offer), count: 0
  end

  test "invalid price re-renders form without creating an offer" do
    sign_in_as users(:two)
    assert_no_difference "MarketOffer.count" do
      post brainrot_card_market_offers_path(brainrot_cards(:two)), params: { market_offer: { price: "1.5" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]"
    assert_select "input[name='market_offer[price]']"
  end

  test "other users cannot list a card or withdraw an offer" do
    sign_in_as users(:two)
    get new_brainrot_card_market_offer_path(brainrot_cards(:one))
    assert_response :not_found
    assert_no_difference "MarketOffer.count" do
      post brainrot_card_market_offers_path(brainrot_cards(:one)), params: { market_offer: { price: 100 } }
      assert_response :not_found
      delete market_offer_path(market_offers(:one))
      assert_response :not_found
    end
    assert market_offers(:one).reload.active?
  end

  test "listed inventory cards allow withdrawal and cannot be listed twice" do
    sign_in_as users(:one)
    get inventory_index_path
    assert_select "form[action=?]", market_offer_path(market_offers(:one), return_to: "inventory")
    assert_select "a[href=?]", new_brainrot_card_market_offer_path(brainrot_cards(:one)), count: 0
    assert_no_difference "MarketOffer.count" do
      post brainrot_card_market_offers_path(brainrot_cards(:one)), params: { market_offer: { price: 200 } }
    end
    assert_redirected_to inventory_index_path
    delete market_offer_path(market_offers(:one)), params: { return_to: "inventory" }
    assert_redirected_to inventory_index_path
    assert market_offers(:one).reload.withdrawn?
    follow_redirect!
    assert_select "a[href=?]", new_brainrot_card_market_offer_path(brainrot_cards(:one))
  end

  test "buy button uses stored price and adds card to buyer inventory" do
    sign_in_as users(:two)
    get marketplace_index_path
    assert_select "form[action=?]", purchase_market_offer_path(market_offers(:one))
    post purchase_market_offer_path(market_offers(:one)), params: { price: 1, buyer_id: users(:one).id }
    assert_redirected_to inventory_index_path
    assert_equal 900, users(:two).reload.coins
    assert_equal 1100, users(:one).reload.coins
    assert_equal users(:two), brainrot_cards(:one).reload.user
    follow_redirect!
    assert_select "h3", brainrot_types(:one).name
    get marketplace_index_path
    assert_select "article#market_offer_#{market_offers(:one).id}", count: 0
  end

  test "self purchase is refused and insufficient coins disable other offers" do
    sign_in_as users(:one)
    post purchase_market_offer_path(market_offers(:one))
    assert_response :unprocessable_entity
    assert_select "h1", text: "Kauf nicht möglich"
    assert_select "a[href=?]", marketplace_index_path, text: "Zurück zum Marktplatz"
    assert market_offers(:one).reload.active?
    sign_in_as users(:two)
    users(:two).update!(coins: 0)
    get marketplace_index_path
    assert_select "button[disabled]", text: "Nicht genügend Coins"
    post purchase_market_offer_path(market_offers(:one))
    assert_response :unprocessable_entity
    assert_select "h1", text: "Kauf nicht möglich"
    assert_select "a[href=?]", marketplace_index_path, text: "Zurück zum Marktplatz"
    assert market_offers(:one).reload.active?
  end

  test "marketplace provides card details for the accessible purchase dialog" do
    sign_in_as users(:two)
    get marketplace_index_path
    offer = market_offers(:one)
    assert_select "dialog[aria-labelledby='purchase-dialog-title']", count: 1
    assert_select "form[action=?][data-action='submit->purchase-confirmation#open']", purchase_market_offer_path(offer) do
      assert_select "[data-turbo-confirm]", count: 0
    end
    form = css_select("form[action='#{purchase_market_offer_path(offer)}']").sole
    assert_equal offer.brainrot_card.brainrot_type.name, form["data-name"]
    assert_equal "Common", form["data-rarity"]
    assert_equal "E", form["data-rank"]
    assert_equal offer.user.username, form["data-seller"]
    assert_equal offer.price.to_s, form["data-price"]
    assert_select "dialog button[type=button]", text: "Abbrechen"
    assert_select "dialog button[type=button]", text: "Kaufen"
  end

  test "unavailable and missing offers show a recoverable error without charging" do
    sign_in_as users(:one)
    balance = users(:one).coins
    post purchase_market_offer_path(market_offers(:two))
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Dieses Angebot ist nicht mehr verfügbar."
    assert_select "a[href=?]", marketplace_index_path, text: "Zurück zum Marktplatz"
    assert_equal balance, users(:one).reload.coins
    assert_equal users(:two), brainrot_cards(:two).reload.user

    post purchase_market_offer_path(id: MarketOffer.maximum(:id) + 1)
    assert_response :not_found
    assert_select "h1", text: "Kauf nicht möglich"
    assert_equal balance, users(:one).reload.coins
  end

  test "a stale repeated purchase shows an error and never charges twice" do
    sign_in_as users(:two)
    post purchase_market_offer_path(market_offers(:one))
    assert_redirected_to inventory_index_path
    balances = User.order(:id).pluck(:coins)
    post purchase_market_offer_path(market_offers(:one))
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Dieses Angebot ist nicht mehr verfügbar."
    assert_equal balances, User.order(:id).pluck(:coins)
    assert_equal users(:two), brainrot_cards(:one).reload.user
  end

  test "pagination displays older offers instead of dropping them" do
    user = users(:two)
    25.times do
      card = user.brainrot_cards.create!(brainrot_type: brainrot_types(:one), rank: ranks(:one), pack_opening: pack_openings(:two))
      MarketOfferCreator.call(user: user, card: card, price: 10)
    end
    sign_in_as user
    get marketplace_index_path
    assert_select ".offer-card", count: 24
    assert_select "a[href=?]", marketplace_index_path(page: 2)
    get marketplace_index_path(page: 2)
    assert_select ".offer-card", count: 2
    assert_select "a[href=?]", marketplace_index_path(page: 1)
  end
end
