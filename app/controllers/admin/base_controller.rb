class Admin::BaseController < ApplicationController
  before_action :require_admin
  after_action :prevent_admin_caching
  helper_method :admin_policy, :user_policy
  rescue_from Admin::Forbidden, with: :forbidden

  private

  def require_admin
    forbidden unless admin_policy.access?
  end

  def admin_policy(record = nil)
    AdminPolicy.new(Current.user, record)
  end

  def user_policy(record)
    UserPolicy.new(Current.user, record)
  end

  def authorize_admin!(record, action)
    raise Admin::Forbidden unless admin_policy(record).public_send("#{action}?")
  end

  def forbidden
    render "admin/shared/forbidden", status: :forbidden
  end

  def prevent_admin_caching
    response.headers["Cache-Control"] = "no-store"
  end

  def paginate(scope)
    @page = (Integer(params[:page], exception: false) || 1).clamp(1, 100_000)
    records = scope.offset((@page - 1) * 25).limit(26).to_a
    @has_next_page = records.size > 25
    records.first(25)
  end
end
