require "test_helper"

class MarketplaceFiltersTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:two) }

  test "name rarity and rank filters combine and ignore letter case in names" do
    get marketplace_index_path(q: "  TRALALERO  ", rarity: "common", rank: "E")
    assert_response :success
    assert_select "article#market_offer_#{market_offers(:one).id}"
    assert_select "input[name=q][value='TRALALERO']"
    get marketplace_index_path(q: "tralalero", rarity: "legendary", rank: "E")
    assert_select ".offer-card", count: 0
    assert_select "h2", "Keine passenden Angebote."
    get marketplace_index_path(rank: "SS")
    assert_select "article#market_offer_#{market_offers(:one).id}", count: 0
  end

  test "wildcards and SQL-like names are treated as literal text" do
    [ "%", "_", "' OR 1=1 --" ].each do |query|
      get marketplace_index_path(q: query)
      assert_response :success
      assert_select ".offer-card", count: 0
    end
    get marketplace_index_path(rarity: "invalid", rank: "invalid", page: "-100")
    assert_response :success
    assert_select "article#market_offer_#{market_offers(:one).id}"
  end

  test "pagination retains all filter values and excludes unrelated offers" do
    type = BrainrotType.create!(name: "Filter Dragon", rarity: :legendary, base_value: 200)
    25.times do
      card = users(:one).brainrot_cards.create!(brainrot_type: type, rank: ranks(:one), pack_opening: pack_openings(:one))
      MarketOfferCreator.call(user: users(:one), card: card, price: 100)
    end
    filters = { q: "Dragon", rarity: "legendary", rank: "E" }
    get marketplace_index_path(filters)
    assert_select ".offer-card", count: 24
    assert_select "a[href=?]", marketplace_index_path(filters.merge(page: 2))
    get marketplace_index_path(filters.merge(page: 2))
    assert_select ".offer-card", count: 1
    assert_select "a[href=?]", marketplace_index_path(filters.merge(page: 1))
    assert_select "article#market_offer_#{market_offers(:one).id}", count: 0
  end
end
