class RankPull < ApplicationRecord
  belongs_to :user
  belongs_to :brainrot_card
  belongs_to :rank

  validates :coins_spent, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :card_belongs_to_user, on: :create

  private

  def card_belongs_to_user
    if brainrot_card && user && brainrot_card.user != user
      errors.add(:brainrot_card, "must belong to the user")
    end
  end
end
