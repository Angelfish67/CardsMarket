require "test_helper"

class BrainrotTypeTest < ActiveSupport::TestCase
  test "image URLs are optional and normalized" do
    type = brainrot_types(:one)
    type.update!(image_url: "  https://images.example.test/card.png?size=800  ")
    assert_equal "https://images.example.test/card.png?size=800", type.reload.image_url
    type.update!(image_url: " ")
    assert_nil type.reload.image_url
  end

  test "image URLs reject unsafe schemes credentials and invalid syntax" do
    type = brainrot_types(:one)
    [ "javascript:alert(1)", "data:image/svg+xml,<svg/>", "http://example.test/card.jpg",
      "//example.test/card.png", "https:///card.png", "https://user:password@example.test/card.png",
      "https://exa mple.test/card.png", "file:///tmp/card.png" ].each do |value|
      type.image_url = value
      assert_not type.valid?, value
      assert type.errors[:image_url].any?, value
    end
    type.image_url = "https://example.test/" + "a" * 2048
    assert_not type.valid?
  end
end
