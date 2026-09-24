require "test_helper"

class AccountManagerTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "account policy only allows active users to manage themselves" do
    assert AccountPolicy.new(users(:one), users(:one)).update?
    assert_not AccountPolicy.new(users(:one), users(:two)).update?
    assert_not AccountPolicy.new(nil, users(:one)).deactivate?
    users(:one).update!(suspended: true)
    assert_not AccountPolicy.new(users(:one), users(:one)).deactivate?
    assert_raises(AccountManager::Forbidden) do
      AccountManager.call(user: users(:one), current_password: "secure password", action: :profile, attributes: { username: "changed" })
    end
  end

  test "failed deactivation rolls back offers and keeps sessions" do
    user = users(:one)
    session = user.sessions.create!
    user.define_singleton_method(:save!) { raise ActiveRecord::RecordInvalid, self }
    assert_raises(ActiveRecord::RecordInvalid) do
      AccountManager.call(user: user, current_password: "secure password", action: :deactivate, attributes: { confirmation: "1" })
    end
    assert_not user.reload.suspended?
    assert market_offers(:one).reload.active?
    assert Session.exists?(session.id)
  end

  test "concurrent admin deactivations retain one active admin" do
    users(:one).update!(role: :admin)
    users(:two).update!(role: :admin)
    outcomes = [ users(:one).id, users(:two).id ].map do |id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          AccountManager.call(user: User.find(id), current_password: "secure password",
            action: :deactivate, attributes: { confirmation: "1" })
          :ok
        rescue ActiveRecord::RecordInvalid
          :denied
        end
      end
    end.map(&:value)
    assert_equal 1, outcomes.count(:ok)
    assert_equal 1, outcomes.count(:denied)
    assert_equal 1, User.admin.where(suspended: false).count
  end

  test "stale gameplay requests cannot trade or spend after deactivation" do
    user = User.find(users(:two).id)
    users(:two).update!(suspended: true)
    assert_no_difference [ "PackOpening.count", "RankPull.count", "MarketOffer.count" ] do
      assert_raises(GameplayError) { PackOpener.call(user: user, pack: packs(:two)) }
      assert_raises(GameplayError) { RankPuller.call(user: user, card: brainrot_cards(:two)) }
      assert_raises(GameplayError) { MarketOfferCreator.call(user: user, card: brainrot_cards(:two), price: 100) }
      assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: user, offer: market_offers(:one)) }
    end
    assert_equal 1000, user.reload.coins
    assert market_offers(:one).reload.active?
    users(:two).update!(suspended: false)
    users(:one).update!(suspended: true)
    assert_raises(GameplayError) { MarketOfferBuyer.call(buyer: user, offer: market_offers(:one)) }
  end
end
