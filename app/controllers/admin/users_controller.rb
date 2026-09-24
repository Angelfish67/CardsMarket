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

  def credit_coins
    @user = User.find(params[:id])
    credit = params.expect(credit: [ :amount, :reason ])
    @credit_amount = credit[:amount]
    @credit_reason = credit[:reason]
    Admin::CoinGranter.call(actor: Current.user, user: @user, amount: @credit_amount, reason: @credit_reason)
    redirect_to edit_admin_user_path(@user, anchor: "coins"),
      notice: "Coins gutgeschrieben. #{@user.username} hat jetzt #{@user.coins} Coins.", status: :see_other
  rescue GameplayError => error
    @user.errors.add(:base, error.message)
    render :edit, status: :unprocessable_entity
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
