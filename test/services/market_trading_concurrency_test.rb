require "test_helper"
require "timeout"

class MarketTradingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @traders = 3.times.map do |number|
      User.create!(username: "market_race_#{number}", email_address: "market_race_#{number}@example.com", password: "a secure passphrase")
    end
    @seller, @buyer, @other_buyer = @traders
    @card = PackOpener.call(user: @seller, pack: packs(:starter)).brainrot_cards.first
  end

  teardown do
    ids = @traders.map(&:id)
    MarketOffer.where(user_id: ids).delete_all
    RankPull.where(user_id: ids).delete_all
    BrainrotCard.where(user_id: ids).delete_all
    PackOpening.where(user_id: ids).delete_all
    User.where(id: ids).delete_all
  end

  test "simultaneous listings create only one active offer" do
    results = concurrently(*2.times.map do
      -> do
        user = User.find(@seller.id)
        card = BrainrotCard.find(@card.id)
        -> { MarketOfferCreator.call(user: user, card: card, price: 100) }
      end
    end)
    assert_equal [ :ok, :rejected ].sort, results.sort
    assert_equal 1, @card.market_offers.active.count
  end

  test "two buyers cannot buy the same card" do
    offer = MarketOfferCreator.call(user: @seller, card: @card, price: 100)
    results = concurrently(*[ @buyer, @other_buyer ].map do |trader|
      -> do
        buyer = User.find(trader.id)
        snapshot = MarketOffer.find(offer.id)
        -> { MarketOfferBuyer.call(buyer: buyer, offer: snapshot) }
      end
    end)
    assert_equal [ :ok, :rejected ].sort, results.sort
    assert offer.reload.sold?
    assert_equal offer.buyer_id, @card.reload.user_id
    assert_equal 1100, @seller.reload.coins
    assert_equal [ 900, 1000 ], [ @buyer.reload.coins, @other_buyer.reload.coins ].sort
    assert_equal 3000, @traders.sum { |user| user.reload.coins }
  end

  test "withdrawal and purchase cannot both succeed" do
    offer = MarketOfferCreator.call(user: @seller, card: @card, price: 100)
    results = concurrently(
      -> do
        buyer = User.find(@buyer.id)
        snapshot = MarketOffer.find(offer.id)
        -> { MarketOfferBuyer.call(buyer: buyer, offer: snapshot) }
      end,
      -> do
        seller = User.find(@seller.id)
        snapshot = MarketOffer.find(offer.id)
        -> { MarketOfferWithdrawer.call(user: seller, offer: snapshot) }
      end
    )
    assert_equal [ :ok, :rejected ].sort, results.sort
    assert_includes %w[sold withdrawn], offer.reload.status
    assert_equal(offer.sold? ? @buyer.id : @seller.id, @card.reload.user_id)
    assert_equal(offer.sold? ? 900 : 1000, @buyer.reload.coins)
    assert_equal 3000, @traders.sum { |user| user.reload.coins }
  end

  test "opposite purchases use stable wallet locks and both finish" do
    other_card = PackOpener.call(user: @buyer, pack: packs(:starter)).brainrot_cards.first
    first_offer = MarketOfferCreator.call(user: @seller, card: @card, price: 100)
    second_offer = MarketOfferCreator.call(user: @buyer, card: other_card, price: 100)
    results = concurrently(*[ [ @buyer, first_offer ], [ @seller, second_offer ] ].map do |trader, offer|
      -> do
        buyer = User.find(trader.id)
        snapshot = MarketOffer.find(offer.id)
        -> { MarketOfferBuyer.call(buyer: buyer, offer: snapshot) }
      end
    end)
    assert_equal [ :ok, :ok ], results
    assert_equal @buyer.id, @card.reload.user_id
    assert_equal @seller.id, other_card.reload.user_id
    assert_equal 1000, @seller.reload.coins
    assert_equal 1000, @buyer.reload.coins
  end

  private

  def concurrently(*preparations)
    ready = Queue.new
    start = Queue.new
    threads = preparations.map do |prepare|
      Thread.new do
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection_pool.with_connection do
            action = prepare.call
            ready << true
            start.pop
            begin
              action.call
              :ok
            rescue GameplayError
              :rejected
            end
          end
        end
      end
    end
    Timeout.timeout(15) do
      threads.size.times { ready.pop }
      threads.size.times { start << true }
      threads.map(&:value)
    end
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
  end
end
