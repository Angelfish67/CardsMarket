class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_registration_path, alert: "Bitte versuche es später erneut." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: [ :username, :email_address, :password, :password_confirmation ]))

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url(@user), notice: "Willkommen bei Brainrot Market!"
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:base, "Benutzername oder E-Mail-Adresse ist bereits vergeben.")
    render :new, status: :unprocessable_entity
  end
end
