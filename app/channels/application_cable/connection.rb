module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id

    def connect
      session = Session.usable.includes(:user)
        .find_by(id: cookies.signed[:session_id])
      reject_unauthorized_connection unless session

      self.current_user = session.user
      self.session_id = session.id
    end

    def session_active?
      Session.usable.where(id: session_id, user_id: current_user.id).exists?
    end
  end
end
