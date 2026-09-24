class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record = nil)
    @user, @record = user, record
  end

  def authenticated?
    user.present? && !user.suspended?
  end

  def admin?
    authenticated? && user.admin?
  end
end
