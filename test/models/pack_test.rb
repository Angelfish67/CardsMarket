require "test_helper"

class PackTest < ActiveSupport::TestCase
  test "new and existing packs allow all rarities by default" do
    assert_equal BrainrotType.rarities.keys, Pack.new.allowed_rarities
    assert_equal BrainrotType.rarities.keys, packs(:beginner).allowed_rarities
  end

  test "rarities must be a nonempty known selection and checkbox blanks are removed" do
    pack = packs(:beginner)
    pack.allowed_rarities = [ "", "rare", "rare", "legendary" ]
    assert pack.valid?
    assert_equal %w[rare legendary], pack.allowed_rarities
    [ [], [ "" ], nil, [ "common", "mythic" ] ].each do |selection|
      pack.allowed_rarities = selection
      assert_not pack.valid?, "Accepted invalid selection: #{selection.inspect}"
    end
  end

  test "database rejects invalid selections without validations" do
    [ "ARRAY[]::varchar[]", "NULL", "ARRAY['mythic']::varchar[]", "ARRAY['rare', NULL]::varchar[]" ].each do |selection|
      assert_raises(ActiveRecord::StatementInvalid) do
        Pack.transaction(requires_new: true) do
          Pack.connection.execute("UPDATE packs SET allowed_rarities = #{selection} WHERE id = #{packs(:beginner).id}")
        end
      end
    end
  end

  test "chances use only allowed rarities with active types" do
    pack = packs(:beginner)
    pack.allowed_rarities = %w[rare epic legendary]
    chances = pack.rarity_chances(available_rarities: %w[common rare legendary])
    assert_equal %w[rare legendary], chances.keys
    assert_in_delta 100, chances.values.sum
    assert_in_delta 1000.0 / 11, chances["rare"]
    assert_in_delta 100.0 / 11, chances["legendary"]
    assert_equal({}, pack.rarity_chances(available_rarities: [ "common" ]))
  end
end
