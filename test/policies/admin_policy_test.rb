require "test_helper"

class AdminPolicyTest < ActiveSupport::TestCase
  test "only active admins have administration rights" do
    trader = users(:one)
    admin = users(:two)
    admin.role = :admin
    assert_not AdminPolicy.new(nil).access?
    assert_not AdminPolicy.new(trader).access?
    assert AdminPolicy.new(admin).access?
    assert AdminPolicy.new(admin, brainrot_types(:one)).update?
    assert_not AdminPolicy.new(admin, ranks(:one)).create?
    assert_not AdminPolicy.new(admin, users(:one)).update?
    admin.suspended = true
    assert_not AdminPolicy.new(admin).access?
    assert_not UserPolicy.new(admin, trader).update?
  end

  test "admins do not gain ownership of other users cards" do
    user = users(:one)
    user.role = :admin
    assert BrainrotCardPolicy.new(user, brainrot_cards(:one)).manage?
    assert_not BrainrotCardPolicy.new(user, brainrot_cards(:two)).manage?
    assert_not BrainrotCardPolicy.new(nil, brainrot_cards(:one)).manage?
    assert_not UserPolicy.new(user, user).suspend?
    assert UserPolicy.new(user, users(:two)).suspend?
  end
end
