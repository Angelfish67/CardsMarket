class Admin::UsersController < Admin::BaseController
  def index
    raise Admin::Forbidden unless user_policy(nil).index?

    users = User.order(:id)
    @query = params[:q].to_s.strip.first(100)
    if @query.present?
      term = "%#{User.sanitize_sql_like(@query)}%"
      users = users.where("username ILIKE :term OR email_address ILIKE :term", term: term)
    end
    @users = paginate(users)
  end

  def edit
    @user = User.find(params[:id])
    raise Admin::Forbidden unless user_policy(@user).update?
  end

  def update
    @user = User.find(params[:id])
    Admin::UserUpdater.call(actor: Current.user, user: @user,
      attributes: params.expect(user: [ :role, :suspended ]).to_h.symbolize_keys)
    redirect_to admin_users_path, notice: "Berechtigungen gespeichert. Bestehende Sitzungen wurden bei Änderungen beendet.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end
end
