require "test_helper"

class Admin::CoinGranterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  setup { users(:one).update!(role: :admin) }

  test "grants add coins and audit balances amount and reason" do
    session = users(:two).sessions.create!
    assert_difference "AdminActivity.count", 1 do
      Admin::CoinGranter.call(actor: users(:one), user: users(:two), amount: "250", reason: " Wettbewerb ")
    end
    assert_equal 1250, users(:two).reload.coins
    assert_equal 1000, users(:one).reload.coins
    assert Session.exists?(session.id)
    activity = AdminActivity.last
    assert_equal users(:one), activity.admin
    assert_equal users(:two).id, activity.subject_id
    assert_equal "coins_granted", activity.action
    assert_equal [ 1000, 1250 ], activity.details["coins"]
    assert_equal [ nil, 250 ], activity.details["amount"]
    assert_equal [ nil, "Wettbewerb" ], activity.details["reason"]
  end

  test "only active admins may grant even with stale actor objects" do
    actor = User.find(users(:one).id)
    users(:one).update!(role: :trader)
    assert_raises(Admin::Forbidden) { Admin::CoinGranter.call(actor: actor, user: users(:two), amount: 5) }
    users(:one).update!(role: :admin, suspended: true)
    assert_raises(Admin::Forbidden) { Admin::CoinGranter.call(actor: actor, user: users(:two), amount: 5) }
    assert_equal 1000, users(:two).reload.coins
  end

  test "invalid amounts reasons and overflow do not change balances or audit" do
    assert_no_difference "AdminActivity.count" do
      [ "", "0", "-1", "1.5", "1e3", "abc", (User::MAX_COINS + 1).to_s ].each do |amount|
        assert_raises(GameplayError) { Admin::CoinGranter.call(actor: users(:one), user: users(:two), amount: amount) }
      end
      assert_raises(GameplayError) { Admin::CoinGranter.call(actor: users(:one), user: users(:two), amount: 1, reason: "a" * 251) }
      users(:two).update!(coins: User::MAX_COINS)
      assert_raises(GameplayError) { Admin::CoinGranter.call(actor: users(:one), user: users(:two), amount: 1) }
      assert_equal User::MAX_COINS, users(:two).reload.coins
    end
  end

  test "an admin can grant coins to their own account" do
    Admin::CoinGranter.call(actor: users(:one), user: users(:one), amount: 100)
    assert_equal 1100, users(:one).reload.coins
  end

  test "a failed audit rolls the credit back" do
    original = AdminActivity.method(:record!)
    AdminActivity.define_singleton_method(:record!) { |**| raise ActiveRecord::RecordInvalid.new(AdminActivity.new) }
    assert_raises(ActiveRecord::RecordInvalid) do
      Admin::CoinGranter.call(actor: users(:one), user: users(:two), amount: 500)
    end
    assert_equal 1000, users(:two).reload.coins
    assert_equal 0, AdminActivity.where(action: "coins_granted").count
  ensure
    AdminActivity.define_singleton_method(:record!, original) if original
  end

  test "concurrent grants preserve both additions" do
    actor_id = users(:one).id
    user_id = users(:two).id
    [ 100, 250 ].map do |amount|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Admin::CoinGranter.call(actor: User.find(actor_id), user: User.find(user_id), amount: amount)
        end
      end
    end.each(&:value)
    assert_equal 1350, users(:two).reload.coins
    changes = AdminActivity.where(action: "coins_granted").order(:id).pluck(:details).map { |d| d["coins"] }
    assert_equal 2, changes.length
    assert_equal 1000, changes.first.first
    assert_equal changes.first.last, changes.last.first
    assert_equal 1350, changes.last.last
  end
end
