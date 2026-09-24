module ApplicationHelper
  def brainrot_image_source(type)
    type.image.attached? ? url_for(type.image) : type.image_url.presence
  end
end
