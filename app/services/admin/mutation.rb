class Admin::Mutation
  def self.call(actor:, record:, action:)
    record.class.transaction do
      raise Admin::Forbidden unless AdminPolicy.new(actor.reload, record).public_send("#{action}?")

      image_before = image_label(record) if record.persisted?
      yield
      deleted_attributes = record.attributes.except("id", "created_at", "updated_at").transform_values { |value| [ value, nil ] } if action == "destroy"
      details = deleted_attributes || record.saved_changes.except("created_at", "updated_at")
      image_after = image_label(record) unless record.destroyed?
      details["image"] = [ image_before, image_after ] if image_before != image_after
      AdminActivity.record!(admin: actor, subject: record, action: action, details: details)
      record
    end
  end

  def self.image_label(record)
    return unless record.is_a?(BrainrotType) && record.image.attached?

    "#{record.image.filename} (##{record.image.blob.id})"
  end
  private_class_method :image_label
end
