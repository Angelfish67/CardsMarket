class BrainrotType < ApplicationRecord
  RARITY_WEIGHTS = { "common" => 60, "uncommon" => 25, "rare" => 10, "epic" => 4, "legendary" => 1 }.freeze

  has_many :brainrot_cards, dependent: :restrict_with_error
  has_one_attached :image
  validate :uploaded_image_is_valid

  scope :active, -> { where(active: true) }
  validates :active, inclusion: { in: [ true, false ] }
  validates :name, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }

  normalizes :image_url, with: ->(value) { value.strip.presence }
  validates :image_url, length: { maximum: 2048 }, allow_nil: true
  validate :image_url_is_https

  enum :rarity, { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4 }, validate: true

  validates :name, presence: true, uniqueness: true
  validates :base_value, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: User::MAX_COINS }
  private

  def uploaded_image_is_valid
    return unless image.attached?

    allowed = %w[image/png image/jpeg image/webp]
    errors.add(:image, "muss PNG, JPG oder WebP sein.") unless allowed.include?(image.blob.content_type)
    errors.add(:image, "darf maximal 5 MB groß sein.") if image.blob.byte_size > 5.megabytes
    upload = attachment_changes["image"]&.attachable
    if upload.respond_to?(:tempfile)
      detected_type = Marcel::MimeType.for(upload.tempfile)
      upload.tempfile.rewind
      errors.add(:image, "enthält keine unterstützte Bilddatei.") unless allowed.include?(detected_type)
    end
  end

  def image_url_is_https
    return if image_url.blank?

    uri = URI.parse(image_url)
    unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
      errors.add(:image_url, "muss ein HTTPS-Bildlink ohne Zugangsdaten sein.")
    end
  rescue URI::InvalidURIError
    errors.add(:image_url, "ist kein gültiger HTTPS-Bildlink.")
  end
end
