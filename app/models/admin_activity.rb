class AdminActivity < ApplicationRecord
  belongs_to :admin, class_name: "User"
  validates :action, :subject_type, :subject_id, presence: true

  def self.record!(admin:, subject:, action:, details: {})
    create!(admin: admin, subject_type: subject.class.name, subject_id: subject.id,
      action: action, details: details)
  end
end
