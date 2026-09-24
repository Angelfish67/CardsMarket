class MarketplaceChannel < ApplicationCable::Channel
  STREAM = "marketplace"

  def subscribed
    return reject unless current_user && connection.session_active?

    stream_from STREAM, coder: ActiveSupport::JSON do |message|
      transmit message if active_session?
    end
  end

  # Reconcile the visible cards after subscribing or reconnecting, so offers
  # sold during a connection interruption also disappear.
  def synchronize(data)
    return unless active_session?

    ids = Array(data["offer_ids"]).first(MarketplaceController::PAGE_SIZE)
      .select { |id| id.is_a?(Integer) && id.positive? }.uniq
    active_ids = MarketOffer.active.where(id: ids).pluck(:id)
    transmit({ type: "remove_offers", offer_ids: ids - active_ids })
  end

  private

  def active_session?
    return true if current_user && connection.session_active?

    stop_all_streams
    connection.close(reconnect: false)
    false
  end
end
