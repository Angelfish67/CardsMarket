class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Bitte versuche es später erneut." }

  def new
  end

  def create
    credentials = params.permit(:email_address, :password)
    # Always pass both keys, including for incomplete requests. authenticate_by
    # performs BCrypt work for unknown accounts as well as incorrect passwords.
    email = credentials[:email_address]
    password = credentials[:password]
    valid_input = email.is_a?(String) && password.is_a?(String) && password.bytesize <= 72

    if valid_input && (user = User.authenticate_by(email_address: email, password: password)) && !user.suspended?
      destination = after_authentication_url(user)
      start_new_session_for user
      redirect_to destination
    else
      redirect_to new_session_path, alert: "E-Mail-Adresse oder Passwort ist ungültig."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: "Du bist abgemeldet."
  end
end
