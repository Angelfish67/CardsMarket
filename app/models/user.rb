class User < ApplicationRecord
  MAX_COINS = 2_147_483_647 # Upper bound of the PostgreSQL integer column.

  has_many :admin_activities, foreign_key: :admin_id, dependent: :restrict_with_error
  after_update_commit :revoke_sessions_after_permission_change

  has_secure_password reset_token: false
  validates :password, length: { minimum: 12 }, allow_nil: true
  has_many :sessions, dependent: :destroy
  has_many :brainrot_cards, dependent: :restrict_with_error
  has_many :market_offers, dependent: :restrict_with_error
  has_many :purchases, class_name: "MarketOffer", foreign_key: :buyer_id, inverse_of: :buyer, dependent: :restrict_with_error
  has_many :pack_openings, dependent: :restrict_with_error
  has_many :rank_pulls, dependent: :restrict_with_error

  validates :suspended, inclusion: { in: [ true, false ] }

  enum :role, { trader: 0, admin: 1 }, validate: true

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :username, with: ->(name) { name.strip.downcase }
  validates :username, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :coins, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_COINS }
  def starter_pack_pending?
    !starter_pack_opened_at? && !pack_openings.exists?(starter: true)
  end

  private

  def revoke_sessions_after_permission_change
    sessions.destroy_all if saved_change_to_role? || saved_change_to_suspended?
  end
end
