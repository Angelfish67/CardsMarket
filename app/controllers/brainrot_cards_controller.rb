class BrainrotCardsController < ApplicationController
  def show
    @card = Current.user.brainrot_cards.includes(:rank, :pack_opening, brainrot_type: { image_attachment: :blob }).find(params[:id])
    raise ActiveRecord::RecordNotFound unless BrainrotCardPolicy.new(Current.user, @card).manage?

    @offer = @card.market_offers.active.first
    @rank_pulls = @card.rank_pulls.where(user: Current.user).includes(:rank).order(id: :desc).limit(10)
  end
end
