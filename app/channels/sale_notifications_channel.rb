class SaleNotificationsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user && connection.session_active?

    # Never accept a user id or stream name from the client.
    stream_for current_user, coder: ActiveSupport::JSON do |message|
      if connection.session_active?
        transmit message
      else
        stop_all_streams
        connection.close(reconnect: false)
      end
    end
  end
end
