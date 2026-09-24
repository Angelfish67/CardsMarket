require "test_helper"
require_relative "../test_helpers/scripted_random"

class WeightedRankDrawTest < ActiveSupport::TestCase
  test "weighted draw handles both sides of each probability boundary" do
    pool = [ ranks(:one), ranks(:two), ranks(:ss) ]
    { 0 => "E", 49 => "E", 50 => "A", 52 => "A", 53 => "SS" }.each do |ticket, expected|
      assert_equal expected, WeightedRankDraw.call(ranks: pool, random: ScriptedRandom.new(ticket)).name
    end
  end

  test "empty rank pool is rejected" do
    assert_raises(GameplayError) { WeightedRankDraw.call(ranks: []) }
  end
end
