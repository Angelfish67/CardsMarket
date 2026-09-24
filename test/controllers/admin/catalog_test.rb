require "test_helper"

class Admin::CatalogTest < ActionDispatch::IntegrationTest
  setup do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
  end

  test "creating and updating catalog entries produces an audit record" do
    assert_difference [ "BrainrotType.count", "AdminActivity.count" ], 1 do
      post admin_brainrot_types_path, params: { brainrot_type: { name: "Test Character", rarity: "rare", base_value: 150, description: "Test", active: true } }
    end
    assert_redirected_to admin_brainrot_types_path
    type = BrainrotType.find_by!(name: "Test Character")
    assert_equal users(:one), AdminActivity.last.admin
    assert_difference "AdminActivity.count", 1 do
      patch admin_brainrot_type_path(type), params: { brainrot_type: { base_value: 200, active: false } }
    end
    assert_not type.reload.active?
    assert_equal 200, type.base_value
    get admin_activities_path
    assert_response :success
    assert_select "td", text: "Bearbeitet"
  end

  test "catalog buttons deactivate and reactivate an already owned card type" do
    type = brainrot_types(:one)
    original_card_ids = type.brainrot_cards.ids.sort
    get admin_brainrot_types_path
    assert_select "#brainrot_type_#{type.id} form[action=?]", admin_brainrot_type_path(type) do
      assert_select "input[name='brainrot_type[active]'][value=false]", count: 1
      assert_select "button", text: "Deaktivieren"
    end

    assert_difference "AdminActivity.count", 1 do
      patch admin_brainrot_type_path(type), params: { brainrot_type: { active: "false" } }
    end
    assert_redirected_to admin_brainrot_types_path
    assert_not type.reload.active?
    assert_equal [ true, false ], AdminActivity.last.details.fetch("active")
    assert_equal original_card_ids, type.brainrot_cards.ids.sort
    follow_redirect!
    assert_select "#brainrot_type_#{type.id} .admin-badge", text: "Deaktiviert"
    assert_select "#brainrot_type_#{type.id} form[action=?]", admin_brainrot_type_path(type) do
      assert_select "input[name='brainrot_type[active]'][value=true]", count: 1
      assert_select "button", text: "Aktivieren"
    end

    # Repeating a stale request must not accidentally reactivate the type.
    patch admin_brainrot_type_path(type), params: { brainrot_type: { active: "false" } }
    assert_not type.reload.active?

    assert_difference "AdminActivity.count", 1 do
      patch admin_brainrot_type_path(type), params: { brainrot_type: { active: "true" } }
    end
    assert_redirected_to admin_brainrot_types_path
    assert type.reload.active?
    assert_equal [ false, true ], AdminActivity.last.details.fetch("active")
    follow_redirect!
    assert_select "#brainrot_type_#{type.id} .admin-badge", text: "Aktiv"
    assert_select "#brainrot_type_#{type.id} button", text: "Deaktivieren"
  end

  test "invalid catalog values render errors without auditing or saving" do
    assert_no_difference "AdminActivity.count" do
      patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { base_value: User::MAX_COINS + 1 } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      patch admin_pack_path(packs(:one)), params: { pack: { cards_count: 101 } }
      assert_response :unprocessable_entity
      patch admin_rank_path(ranks(:one)), params: { rank: { multiplier: 10000 } }
      assert_response :unprocessable_entity
      post admin_packs_path, params: { pack: { name: "Invalid starter", starter: true, price: 10, cards_count: 3 } }
      assert_response :unprocessable_entity
    end
  end

  test "rank name and existing pack classification cannot be changed by forged input" do
    patch admin_rank_path(ranks(:one)), params: { rank: { name: "SS", multiplier: 1.5, weight: 40 } }
    assert_redirected_to admin_ranks_path
    assert_equal "E", ranks(:one).reload.name
    assert_equal 1.5, ranks(:one).multiplier
    patch admin_pack_path(packs(:beginner)), params: { pack: { starter: true, price: 50 } }
    assert_redirected_to admin_packs_path
    assert_not packs(:beginner).reload.starter?
    assert_equal 50, packs(:beginner).price
  end

  test "deactivated packs cannot be opened even through a direct request" do
    packs(:beginner).update!(active: false)
    get packs_index_path
    assert_select "form[action=?]", open_pack_path(packs(:beginner)), count: 0
    assert_no_difference [ "PackOpening.count", "BrainrotCard.count" ] do
      post open_pack_path(packs(:beginner))
    end
    assert_redirected_to packs_index_path
    assert_equal 1000, users(:one).reload.coins
  end

  test "deactivated types stay in inventories but are not drawn" do
    patch admin_brainrot_type_path(brainrot_types(:one)), params: { brainrot_type: { active: "false" } }
    assert_redirected_to admin_brainrot_types_path
    opening = PackOpener.call(user: users(:two), pack: packs(:beginner))
    assert opening.brainrot_cards.all? { |card| card.brainrot_type_id == brainrot_types(:two).id }
    assert_equal brainrot_types(:one), brainrot_cards(:one).reload.brainrot_type
  end

  test "admin moderation preserves ownership and records the change" do
    assert_difference "AdminActivity.count", 1 do
      delete admin_market_offer_path(market_offers(:one))
    end
    assert_redirected_to admin_market_offers_path
    assert market_offers(:one).reload.withdrawn?
    assert_equal users(:one), brainrot_cards(:one).reload.user
    assert_equal "moderate", AdminActivity.last.action
  end

  test "admin cannot mutate another users card through trader routes" do
    post brainrot_card_rank_pulls_path(brainrot_cards(:two))
    assert_response :not_found
    post brainrot_card_market_offers_path(brainrot_cards(:two)), params: { market_offer: { price: 100 } }
    assert_response :not_found
  end
end
