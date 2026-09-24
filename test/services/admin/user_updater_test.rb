require "test_helper"

class Admin::UserUpdaterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { users(:one).update!(role: :admin) }

  test "only admins can change permissions" do
    assert_raises(Admin::Forbidden) do
      Admin::UserUpdater.call(actor: users(:two), user: users(:two), attributes: { role: "admin" })
    end
    assert users(:two).reload.trader?
  end

  test "promotion revokes sessions and audits only role or suspension fields" do
    session = users(:two).sessions.create!
    assert_difference "AdminActivity.count", 1 do
      Admin::UserUpdater.call(actor: users(:one), user: users(:two),
        attributes: { role: "admin", coins: 999999, password: "changed password" })
    end
    assert users(:two).reload.admin?
    assert_not Session.exists?(session.id)
    assert_equal 1000, users(:two).coins
    assert users(:two).authenticate("secure password")
    assert_equal [ "role" ], AdminActivity.last.details.keys
  end

  test "cannot remove the final active admin or suspend yourself" do
    assert_no_difference "AdminActivity.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        Admin::UserUpdater.call(actor: users(:one), user: users(:one), attributes: { role: "trader" })
      end
      assert users(:one).reload.admin?
      assert_raises(ActiveRecord::RecordInvalid) do
        Admin::UserUpdater.call(actor: users(:one), user: users(:one), attributes: { suspended: true })
      end
    end
    assert_not users(:one).reload.suspended?
  end

  test "suspension revokes sessions and can be lifted without losing cards" do
    session = users(:two).sessions.create!
    Admin::UserUpdater.call(actor: users(:one), user: users(:two), attributes: { suspended: true })
    assert users(:two).reload.suspended?
    assert_not Session.exists?(session.id)
    assert_equal users(:two), brainrot_cards(:two).reload.user
    Admin::UserUpdater.call(actor: users(:one), user: users(:two), attributes: { suspended: false })
    assert_not users(:two).reload.suspended?
    assert_equal 1000, users(:two).coins
  end

  test "invalid roles do not create an audit entry" do
    assert_no_difference "AdminActivity.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        Admin::UserUpdater.call(actor: users(:one), user: users(:two), attributes: { role: "superadmin" })
      end
    end
    assert users(:two).reload.trader?
  end

  test "simultaneous self demotions retain an active admin" do
    users(:two).update!(role: :admin)
    ids = [ users(:one).id, users(:two).id ]
    results = ids.map do |id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(id)
          Admin::UserUpdater.call(actor: user, user: user, attributes: { role: "trader" })
          :ok
        rescue ActiveRecord::RecordInvalid, Admin::Forbidden
          :denied
        end
      end
    end.map(&:value)
    assert_equal 1, results.count(:ok)
    assert_equal 1, results.count(:denied)
    assert_equal 1, User.admin.where(suspended: false).count
  end
end
