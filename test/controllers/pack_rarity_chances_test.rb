require "test_helper"

class PackRarityChancesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "each pack shows its own chances and unavailable packs cannot be opened" do
    pack = packs(:beginner)
    pack.update!(allowed_rarities: [ "rare", "legendary" ])
    get packs_index_path
    assert_response :success
    assert_select "#pack_#{pack.id} .pack-odds li", count: 1
    assert_select "#pack_#{pack.id} .pack-odds li", text: /Rare.*100 %/
    assert_select "#pack_#{pack.id} .pack-rarity-summary", text: /Rare, Legendary/
    pack.update!(allowed_rarities: [ "legendary" ])
    get packs_index_path
    assert_select "#pack_#{pack.id} button[disabled]", text: "Keine passenden Karten verfügbar"
    assert_select "#pack_#{pack.id} form", count: 0
    assert_no_difference [ "PackOpening.count", "BrainrotCard.count" ] do
      post open_pack_path(pack)
    end
    assert_redirected_to packs_index_path
    assert_match(/anderes Pack/, flash[:alert])
    assert_equal 1000, users(:one).reload.coins
  end
end
