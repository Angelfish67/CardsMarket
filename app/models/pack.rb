class Pack < ApplicationRecord
  has_many :pack_openings, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  validates :active, inclusion: { in: [ true, false ] }
  validates :name, length: { maximum: 100 }

  validates :name, presence: true
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: User::MAX_COINS }
  validates :cards_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :starter, inclusion: { in: [ true, false ] }
  validates :price, numericality: { equal_to: 0 }, if: :starter?
  validates :cards_count, numericality: { equal_to: 3 }, if: :starter?
end
