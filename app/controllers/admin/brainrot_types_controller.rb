class Admin::BrainrotTypesController < Admin::CatalogController
  MODEL = BrainrotType
  LABEL = "Kartentypen"
  FIELDS = %i[ name description rarity base_value active image_url image remove_image ].freeze

  private

  def catalog_attributes
    attributes = super
    upload = attributes.delete(:image)
    remove = ActiveModel::Type::Boolean.new.cast(attributes.delete(:remove_image))
    if upload.present?
      raise ActionController::BadRequest, "Bitte eine Bilddatei auswählen." unless upload.is_a?(ActionDispatch::Http::UploadedFile)

      attributes[:image] = upload
    elsif remove
      attributes[:image] = nil
    end
    attributes
  end
end
