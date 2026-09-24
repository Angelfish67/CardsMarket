class Session < ApplicationRecord
  LIFETIME = 2.weeks

  belongs_to :user
  scope :usable, -> { joins(:user).where(users: { suspended: false }).where(sessions: { created_at: LIFETIME.ago.. }) }
  after_destroy_commit :disconnect_websockets

  private

  def disconnect_websockets
    ActionCable.server.remote_connections.where(current_user: user, session_id: id).disconnect(reconnect: false)
  rescue StandardError => error
    # Delivery also rechecks the session in the DB if Cable is unavailable here.
    Rails.logger.error("Cable disconnect failed for session #{id}: #{error.class}")
  end
end
