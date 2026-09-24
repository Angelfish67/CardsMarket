require "test_helper"

class GameplayConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = User.create!(username: "concurrent_trader", email_address: "race@example.com", password: "a secure passphrase")
  end

  teardown do
    if @user
      RankPull.where(user_id: @user.id).delete_all
      BrainrotCard.where(user_id: @user.id).delete_all
      PackOpening.where(user_id: @user.id).delete_all
      @user.destroy!
    end
  end

  test "simultaneous starter requests award only three cards" do
    results = open_simultaneously(packs(:starter))
    assert_equal [ :opened, :rejected ].sort, results.sort
    assert_equal 3, @user.brainrot_cards.count
    assert_equal 1, @user.pack_openings.count
    assert_equal 1000, @user.reload.coins
    assert @user.starter_pack_opened_at
  end

  test "simultaneous paid requests cannot overspend the wallet" do
    @user.update!(coins: 100)
    results = open_simultaneously(packs(:beginner))
    assert_equal [ :opened, :rejected ].sort, results.sort
    assert_equal 3, @user.brainrot_cards.count
    assert_equal 0, @user.reload.coins
  end

  test "pack and rank pull compete for the same wallet safely" do
    opening = PackOpener.call(user: @user, pack: packs(:starter))
    card = opening.brainrot_cards.first
    card.update!(brainrot_type: brainrot_types(:one), rank: ranks(:one))
    @user.update!(coins: 100)
    pack_id = packs(:beginner).id
    results = run_simultaneously do |user, attempt|
      if attempt.zero?
        PackOpener.call(user: user, pack: Pack.find(pack_id))
      else
        RankPuller.call(user: user, card: BrainrotCard.find(card.id))
      end
    end
    assert_equal [ :opened, :rejected ].sort, results.sort
    assert_equal 0, @user.reload.coins
    assert_equal 2, @user.pack_openings.count + @user.rank_pulls.count
  end

  private

  def open_simultaneously(pack)
    run_simultaneously { |user, attempt| PackOpener.call(user: user, pack: Pack.find(pack.id)) }
  end

  def run_simultaneously
    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do |attempt|
      Thread.new do
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection_pool.with_connection do
            user = User.find(@user.id)
            ready << true
            start.pop
            begin
              yield user, attempt
              :opened
            rescue GameplayError
              :rejected
            end
          end
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.map(&:value)
  end
end
