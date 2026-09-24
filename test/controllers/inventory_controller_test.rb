require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  test "guests are redirected to login" do
    get inventory_index_path
    assert_redirected_to new_session_path
  end

  test "signed in users can access index" do
    sign_in_as users(:one)
    get inventory_index_path
    assert_response :success
  end

  test "sorts names rarity ranks values and dates in both directions using only owned cards" do
    cards = prepare_collection
    expected = {
      "name" => [ cards[1], cards[2], cards[0] ],
      "rarity" => cards,
      "rank" => cards,
      "value" => [ cards[2], cards[0], cards[1] ],
      "created_at" => [ cards[0], cards[2], cards[1] ]
    }
    expected.each do |sort, ascending|
      %w[asc desc].each do |direction|
        get inventory_index_path(sort: sort, direction: direction)
        assert_response :success
        assert_card_order(direction == "asc" ? ascending : ascending.reverse)
        assert_select "select[name=sort] option[selected][value=?]", sort
        assert_select "select[name=direction] option[selected][value=?]", direction
      end
    end
  end

  test "default and invalid sorting use newest cards first" do
    cards = prepare_collection
    [ {}, { sort: "name; DROP TABLE users", direction: "desc; SELECT 1" }, { sort: [ "rank" ], direction: [ "asc" ] } ].each do |params|
      get inventory_index_path(params)
      assert_response :success
      assert_card_order([ cards[1], cards[2], cards[0] ])
      assert_select "select[name=sort] option[selected][value=created_at]"
      assert_select "select[name=direction] option[selected][value=desc]"
    end
  end

  test "rank order is independent of configurable multipliers and ties are stable" do
    cards = prepare_collection
    ranks(:two).update!(multiplier: 0.01)
    get inventory_index_path(sort: "rank", direction: "asc")
    assert_card_order(cards)

    cards.each { |card| card.update!(created_at: Time.zone.parse("2026-01-01 12:00:00")) }
    get inventory_index_path
    assert_card_order(cards.sort_by(&:id).reverse)
  end

  test "empty inventory still shows the empty state" do
    user = User.create!(username: "empty_sort", email_address: "empty_sort@example.com", password: "a long test password")
    sign_in_as user
    get inventory_index_path(sort: "value", direction: "asc")
    assert_response :success
    assert_select ".inventory-card", count: 0
    assert_select ".empty-state"
  end

  private

  def prepare_collection
    sign_in_as users(:one)
    first = brainrot_cards(:one)
    first.brainrot_type.update!(name: "zeta")
    first.update!(created_at: 3.days.ago)
    brainrot_types(:two).update!(name: "Alpha")
    second = users(:one).brainrot_cards.create!(brainrot_type: brainrot_types(:two), rank: ranks(:two),
      pack_opening: pack_openings(:one), created_at: 1.day.ago)
    type = BrainrotType.create!(name: "beta", rarity: :legendary, base_value: 10)
    third = users(:one).brainrot_cards.create!(brainrot_type: type, rank: ranks(:ss),
      pack_opening: pack_openings(:one), created_at: 2.days.ago)
    [ first, second, third ]
  end

  def assert_card_order(cards)
    assert_equal cards.map { |card| brainrot_card_path(card) },
      css_select(".inventory-card > a.card-detail-link").map { |link| link["href"] }
  end
end
