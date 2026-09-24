class BrainrotCard < ApplicationRecord
  belongs_to :user
  belongs_to :brainrot_type
  belongs_to :rank
  belongs_to :pack_opening
  has_many :market_offers, dependent: :restrict_with_error
  has_many :rank_pulls, dependent: :restrict_with_error

  def value
    brainrot_type.base_value * rank.multiplier
  end
end
