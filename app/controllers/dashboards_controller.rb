class DashboardsController < ApplicationController
  def show
    @user = Current.user
  end
end
