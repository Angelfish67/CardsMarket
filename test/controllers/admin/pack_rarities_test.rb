require "test_helper"

class Admin::PackRaritiesTest < ActionDispatch::IntegrationTest
  test "admins create and edit pack rarities with an audit trail" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    get new_admin_pack_path
    assert_select "input[type=checkbox][name='pack[allowed_rarities][]'][checked]", count: 5
    assert_difference [ "Pack.count", "AdminActivity.count" ], 1 do
      post admin_packs_path, params: { pack: { name: "Special pack", price: 250, cards_count: 3,
        active: true, allowed_rarities: [ "", "epic", "legendary" ] } }
    end
    assert_redirected_to admin_packs_path
    pack = Pack.find_by!(name: "Special pack")
    assert_equal %w[epic legendary], pack.allowed_rarities
    assert_difference "AdminActivity.count", 1 do
      patch admin_pack_path(pack), params: { pack: { allowed_rarities: [ "", "rare" ], starter: true } }
    end
    assert_equal [ "rare" ], pack.reload.allowed_rarities
    assert_not pack.starter?
    assert_equal [ %w[epic legendary], [ "rare" ] ], AdminActivity.last.details["allowed_rarities"]
    get edit_admin_pack_path(pack)
    assert_select "input[name='pack[allowed_rarities][]'][checked]", count: 1
    assert_select "input[name='pack[allowed_rarities][]'][value=rare][checked]"
    get admin_activities_path
    assert_select "dt", text: "Erlaubte Seltenheitsstufen"
  end

  test "empty or unknown rarities are rejected and selections survive other errors" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    pack = packs(:beginner)
    [ [ "" ], [ "mythic" ] ].each do |selection|
      assert_no_difference "AdminActivity.count" do
        patch admin_pack_path(pack), params: { pack: { allowed_rarities: selection } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      assert_equal BrainrotType.rarities.keys, pack.reload.allowed_rarities
    end
    patch admin_pack_path(pack), params: { pack: { price: -1, allowed_rarities: [ "", "legendary" ] } }
    assert_response :unprocessable_entity
    assert_select "input[name='pack[allowed_rarities][]'][value=legendary][checked]"
    assert_select "input[name='pack[allowed_rarities][]'][value=common][checked]", count: 0
  end

  test "traders cannot change allowed rarities through admin or pack opening params" do
    sign_in_as users(:two)
    pack = packs(:beginner)
    pack.update!(allowed_rarities: [ "rare" ])
    patch admin_pack_path(pack), params: { pack: { allowed_rarities: [ "common" ] } }
    assert_response :forbidden
    post open_pack_path(pack), params: { allowed_rarities: [ "common" ], pack: { allowed_rarities: [ "common" ] } }
    assert_response :redirect
    opening = users(:two).pack_openings.order(:id).last
    assert_equal [ brainrot_types(:two).id ], opening.brainrot_cards.distinct.pluck(:brainrot_type_id)
    assert_equal [ "rare" ], pack.reload.allowed_rarities
  end
end
