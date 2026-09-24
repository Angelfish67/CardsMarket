class Admin::ActivitiesController < Admin::BaseController
  def index
    @activities = paginate(AdminActivity.includes(:admin).order(id: :desc))
  end
end
