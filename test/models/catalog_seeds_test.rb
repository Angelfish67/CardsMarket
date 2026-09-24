require "test_helper"

class CatalogSeedsTest < ActiveSupport::TestCase
  test "seeding adds the image catalog once and preserves custom settings" do
    existing = brainrot_types(:one)
    existing.update!(base_value: 777, rarity: :epic, active: false,
      image_url: "https://images.example.test/custom.webp")
    seed_file = Rails.root.join("db/seeds.rb")
    load seed_file

    catalog = JSON.parse(Rails.root.join("db/brainrot_catalog.json").read)
    assert_equal 18, catalog.length
    catalog.each do |attributes|
      type = BrainrotType.find_by!(name: attributes.fetch("name"))
      assert type.valid?, type.errors.full_messages.join(", ")
      assert type.image_url.present?
      next if type.id == existing.id

      assert_equal attributes.fetch("image_url"), type.image_url
    end
    assert_equal 777, existing.reload.base_value
    assert existing.epic?
    assert_not existing.active?
    assert_equal "https://images.example.test/custom.webp", existing.image_url

    assert_no_difference [ "BrainrotType.count", "Rank.count", "Pack.count" ] do
      load seed_file
    end
    assert_equal "https://images.example.test/custom.webp", existing.reload.image_url
  end

  test "seeding supplies a missing image without changing the existing card type" do
    type = brainrot_types(:one)
    type.update!(base_value: 321, active: false)
    load Rails.root.join("db/seeds.rb")
    assert type.reload.image_url.start_with?("https://raw.githubusercontent.com/")
    assert_equal 321, type.base_value
    assert_not type.active?
    assert_equal type, brainrot_cards(:one).reload.brainrot_type
  end
end
