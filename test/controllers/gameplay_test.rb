require "test_helper"

class GameplayTest < ActionDispatch::IntegrationTest
  test "guests cannot spend coins or open packs" do
    assert_no_difference [ "PackOpening.count", "BrainrotCard.count", "RankPull.count" ] do
      post open_pack_path(packs(:starter))
      assert_redirected_to new_session_path
      post brainrot_card_rank_pulls_path(brainrot_cards(:one))
      assert_redirected_to new_session_path
    end
  end

  test "starter opens displays three cards and cannot be claimed twice" do
    sign_in_as users(:one)
    post open_pack_path(packs(:starter))
    opening = users(:one).pack_openings.order(:id).last
    assert_redirected_to pack_opening_path(opening)
    follow_redirect!
    assert_select ".collection-card", count: 3
    assert_select "a[href=?]", inventory_index_path
    get pack_opening_path(opening)
    assert_response :success
    assert_no_difference "BrainrotCard.count" do
      post open_pack_path(packs(:starter))
    end
    assert_redirected_to packs_index_path
    follow_redirect!
    assert_select "button[disabled]", text: "Starter-Pack bereits geöffnet"
  end

  test "paid packs ignore submitted price count and user" do
    sign_in_as users(:one)
    assert_difference "BrainrotCard.count", 6 do
      2.times { post open_pack_path(packs(:beginner)), params: { price: 0, cards_count: 99, user_id: users(:two).id } }
    end
    assert_equal 800, users(:one).reload.coins
    assert_equal 1000, users(:two).reload.coins
  end

  test "opening details and rank pulls are private to the owner" do
    sign_in_as users(:two)
    get pack_opening_path(pack_openings(:one))
    assert_response :not_found
    assert_no_difference "RankPull.count" do
      post brainrot_card_rank_pulls_path(brainrot_cards(:one))
      assert_response :not_found
    end
  end

  test "rank pull uses server price and records result" do
    sign_in_as users(:two)
    assert_difference "RankPull.count", 1 do
      post brainrot_card_rank_pulls_path(brainrot_cards(:two)), params: { coins_spent: 0, rank_id: ranks(:ss).id }
    end
    assert_redirected_to inventory_index_path
    assert_equal 800, users(:two).reload.coins
    follow_redirect!
    assert_select "[role=status]", /Rank-Pull:/
  end
end
