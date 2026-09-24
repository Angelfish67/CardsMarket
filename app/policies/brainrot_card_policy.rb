class BrainrotCardPolicy < ApplicationPolicy
  def manage?
    authenticated? && record.user_id == user.id
  end
end
