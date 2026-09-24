class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def update?
    admin? && record.is_a?(User)
  end

  def grant_coins?
    update?
  end

  def suspend?
    update? && record.id != user.id
  end
end
