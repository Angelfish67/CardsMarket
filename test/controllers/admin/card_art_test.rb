require "test_helper"

class Admin::CardArtTest < ActionDispatch::IntegrationTest
  test "admin can save rarity and image with an audit entry and remove the image" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    type = brainrot_types(:one)
    assert_difference "AdminActivity.count", 1 do
      patch admin_brainrot_type_path(type), params: { brainrot_type: { rarity: "legendary", image_url: "https://images.example.test/card.png" } }
    end
    assert_redirected_to admin_brainrot_types_path
    assert type.reload.legendary?
    assert_equal [ nil, "https://images.example.test/card.png" ], AdminActivity.last.details["image_url"]
    get inventory_index_path
    assert_select ".card-rarity-legendary .card-rarity", text: "Legendary"
    assert_select ".collection-art img[src=?][alt=?]", type.image_url, type.name
    assert_select ".collection-art img[referrerpolicy='no-referrer']"
    get edit_admin_brainrot_type_path(type)
    assert_select "input[name='brainrot_type[image_url]']"
    assert_select ".admin-image-preview img[src=?]", type.image_url
    patch admin_brainrot_type_path(type), params: { brainrot_type: { image_url: "" } }
    assert_nil type.reload.image_url
    get inventory_index_path
    assert_select ".collection-art img", count: 0
    assert_select ".card-monogram", text: "TR"
  end

  test "invalid links are rejected and traders cannot edit images or rarity" do
    type = brainrot_types(:one)
    sign_in_as users(:two)
    patch admin_brainrot_type_path(type), params: { brainrot_type: { image_url: "https://images.example.test/card.png", rarity: "legendary" } }
    assert_response :forbidden
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    assert_no_difference "AdminActivity.count" do
      patch admin_brainrot_type_path(type), params: { brainrot_type: { image_url: "javascript:alert(1)" } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
    end
    assert_nil type.reload.image_url
    assert type.common?
  end

  test "packs show actual normalized rarity chances and card art appears on the marketplace" do
    type = brainrot_types(:one)
    type.update!(image_url: "https://images.example.test/card.png")
    sign_in_as users(:two)
    get marketplace_index_path
    assert_select ".collection-art img[src=?]", type.image_url
    get packs_index_path
    assert_select ".rarity-odds .rarity-common", text: /85.7/
    assert_select ".rarity-odds .rarity-rare", text: /14.3/
    assert_select ".rarity-odds .rarity-legendary", count: 0
  end
end
