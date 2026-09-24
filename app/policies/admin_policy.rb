class AdminPolicy < ApplicationPolicy
  def access?
    admin?
  end

  def index?
    access?
  end

  def create?
    access? && (record.is_a?(BrainrotType) || record.is_a?(Pack))
  end

  def update?
    access? && (record.is_a?(BrainrotType) || record.is_a?(Pack) || record.is_a?(Rank))
  end

  def destroy?
    access? && record.is_a?(BrainrotType)
  end

  def moderate?
    access? && record.is_a?(MarketOffer) && record.active?
  end
end
