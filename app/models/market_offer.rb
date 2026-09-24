class MarketOffer < ApplicationRecord
  belongs_to :user
  belongs_to :brainrot_card
  belongs_to :buyer, class_name: "User", optional: true, inverse_of: :purchases

  enum :status, { active: 0, sold: 1, withdrawn: 2 }, validate: true

  validates :price, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: User::MAX_COINS }
  validates :brainrot_card_id, uniqueness: { conditions: -> { where(status: :active) } }, if: :active?
  validates :buyer, :sold_at, presence: true, if: :sold?
  validates :buyer, :sold_at, absence: true, unless: :sold?
  validate :seller_owns_card, if: :active?
  validate :buyer_is_not_seller

  after_update_commit :notify_seller, if: -> { saved_change_to_status? && sold? }
  after_update_commit :remove_from_marketplace, if: -> { saved_change_to_status? && !active? }

  private

  def remove_from_marketplace
    MarketplaceUpdate.broadcast_removal(self)
  end

  def notify_seller
    SaleNotification.broadcast(self)
  end

  def seller_owns_card
    if brainrot_card && user && brainrot_card.user != user
      errors.add(:brainrot_card, "must belong to the seller")
    end
  end

  def buyer_is_not_seller
    errors.add(:buyer, "cannot be the seller") if buyer && buyer == user
  end
end
