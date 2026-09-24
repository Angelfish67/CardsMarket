class Rank < ApplicationRecord
  NAMES = %w[E D C B A SS].freeze

  has_many :brainrot_cards, dependent: :restrict_with_error
  has_many :rank_pulls, dependent: :restrict_with_error

  validates :name, inclusion: { in: NAMES }, uniqueness: true
  validates :multiplier, numericality: { greater_than_or_equal_to: 0.01, less_than_or_equal_to: 9999.99 }
  validates :weight, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: User::MAX_COINS }
end
