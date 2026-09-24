require "test_helper"

class CatalogDeletionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "a type being drawn cannot disappear before the cards are stored" do
    admin = users(:one)
    admin.update!(role: :admin)
    BrainrotType.update_all(active: false)
    type = BrainrotType.create!(name: "Concurrent type", rarity: :common, base_value: 100)
    drawing = Queue.new
    proceed = Queue.new
    deleting = Queue.new
    random = Object.new
    first = true
    random.define_singleton_method(:random_number) do |_limit|
      if first
        first = false
        drawing << true
        proceed.pop
      end
      0
    end
    pull = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        PackOpener.call(user: User.find(users(:two).id), pack: packs(:beginner), random: random)
      end
    end
    drawing.pop
    removal = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        record = BrainrotType.find(type.id)
        Admin::Mutation.call(actor: User.find(admin.id), record: record, action: "destroy") do
          deleting << true
          record.with_lock { record.destroy! }
        end
      rescue ActiveRecord::RecordNotDestroyed
        :referenced
      end
    end
    deleting.pop
    proceed << true
    assert pull.join(10), "Pack opening timed out"
    assert removal.join(10), "Deletion timed out"
    assert_equal 3, pull.value.brainrot_cards.count
    assert_equal :referenced, removal.value
    assert BrainrotType.exists?(type.id)
    assert_equal 0, AdminActivity.where(subject_type: "BrainrotType", subject_id: type.id, action: "destroy").count
  end
end
