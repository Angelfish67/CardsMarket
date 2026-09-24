class InventoryController < ApplicationController
  def index
    @cards = Current.user.brainrot_cards.includes(:rank, brainrot_type: { image_attachment: :blob }).order(created_at: :desc)
    @active_offers = Current.user.market_offers.active.index_by(&:brainrot_card_id)
  end
end
