class PackOpening < ApplicationRecord
  belongs_to :user
  belongs_to :pack
  has_many :brainrot_cards, dependent: :restrict_with_error

  validates :coins_spent, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
