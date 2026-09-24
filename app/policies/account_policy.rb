class AccountPolicy < ApplicationPolicy
  def update?
    authenticated? && record.is_a?(User) && record.id == user.id
  end

  def deactivate?
    update?
  end
end
