class AccountsController < ApplicationController
  before_action :set_account
  after_action :prevent_account_caching
  rate_limit to: 10, within: 3.minutes, only: %i[ update password deactivate ],
    with: -> { redirect_to edit_account_path, alert: "Bitte versuche es später erneut." }
  rescue_from AccountManager::Forbidden, with: -> { head :forbidden }
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_account
  rescue_from ActiveRecord::RecordNotUnique, with: :duplicate_account

  def edit
  end

  def update
    change_account(:profile, %i[ username email_address ],
      "Profildaten gespeichert.", "E-Mail-Adresse geändert. Bitte melde dich erneut an.")
  end

  def password
    change_account(:password, %i[ password password_confirmation ],
      "Passwort geändert.", "Passwort geändert. Alle Sitzungen wurden beendet. Bitte melde dich erneut an.")
  end

  def deactivate
    change_account(:deactivate, %i[ confirmation ],
      "Konto deaktiviert.", "Dein Konto ist deaktiviert. Ein Admin kann es wieder aktivieren.")
  end

  private

  def set_account
    @user = Current.user
    raise AccountManager::Forbidden unless AccountPolicy.new(Current.user, @user).update?
  end

  def change_account(action, fields, notice, signed_out_notice)
    input = params.expect(account: [ :current_password, *fields ]).to_h.symbolize_keys
    signed_out = AccountManager.call(user: @user, current_password: input.delete(:current_password),
      action: action, attributes: input)
    if signed_out
      terminate_session
      redirect_to new_session_path, notice: signed_out_notice, status: :see_other
    else
      redirect_to edit_account_path, notice: notice, status: :see_other
    end
  end

  def invalid_account
    render :edit, status: :unprocessable_entity
  end

  def duplicate_account
    @user.errors.add(:base, "Benutzername oder E-Mail-Adresse ist bereits vergeben.")
    render :edit, status: :unprocessable_entity
  end

  def prevent_account_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
