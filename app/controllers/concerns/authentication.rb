module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    if session_id = cookies.signed[:session_id]
      Session.usable.find_by(id: session_id)
    end
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.fullpath if request.get? || request.head?
    redirect_to new_session_path
  end

  def after_authentication_url(user)
    destination = session.delete(:return_to_after_authenticating)
    # Explicit protected-page destinations take precedence over the welcome flow.
    if destination.is_a?(String) && destination.start_with?("/") &&
        !destination.start_with?("//") && !destination.include?("\\") && destination != root_path
      return destination
    end
    user.starter_pack_pending? && Pack.active.exists?(starter: true) ? packs_index_path(anchor: "starter-pack") : root_path
  end

  def start_new_session_for(user)
    resume_session&.destroy!
    reset_session
    Current.session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    cookies.signed[:session_id] = {
      value: Current.session.id,
      expires: Session::LIFETIME.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production? || request.ssl?
    }
  end

  def terminate_session
    Current.session&.destroy!
    Current.reset
    reset_session
    cookies.delete(:session_id)
  end
end
