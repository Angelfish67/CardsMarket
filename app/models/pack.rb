class Pack < ApplicationRecord
  has_many :pack_openings, dependent: :restrict_with_error

  normalizes :allowed_rarities, with: ->(values) { values.reject(&:blank?).uniq }
  validate :allowed_rarities_are_valid

  def available_types
    BrainrotType.active.where(rarity: allowed_rarities)
  end

  def rarity_chances(available_rarities:)
    WeightedBrainrotDraw.chances(rarities: allowed_rarities & available_rarities)
  end

  scope :active, -> { where(active: true) }
  validates :active, inclusion: { in: [ true, false ] }
  validates :name, length: { maximum: 100 }

  validates :name, presence: true
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: User::MAX_COINS }
  validates :cards_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :starter, inclusion: { in: [ true, false ] }
  validates :price, numericality: { equal_to: 0 }, if: :starter?
  validates :cards_count, numericality: { equal_to: 3 }, if: :starter?

  private

  def allowed_rarities_are_valid
    if allowed_rarities.blank?
      errors.add(:base, "Wähle mindestens eine erlaubte Seltenheitsstufe aus.")
    elsif (allowed_rarities - BrainrotType.rarities.keys).any?
      errors.add(:base, "Die Auswahl enthält eine unbekannte Seltenheitsstufe.")
    end
  end
end
