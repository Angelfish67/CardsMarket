class MarketOffersController < ApplicationController
  before_action :set_card, only: %i[ new create ]

  def new
    if @card.market_offers.active.exists?
      redirect_to marketplace_index_path, alert: "Diese Karte wird bereits angeboten."
    else
      @offer = MarketOffer.new(price: @card.value.ceil)
    end
  end

  def create
    price = params.expect(market_offer: [ :price ])[:price]
    MarketOfferCreator.call(user: Current.user, card: @card, price: price)
    redirect_to marketplace_index_path, notice: "Deine Karte wird jetzt auf dem Marktplatz angeboten.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @offer = error.record
    render :new, status: :unprocessable_entity
  rescue GameplayError => error
    redirect_to inventory_index_path, alert: error.message, status: :see_other
  end

  def destroy
    offer = Current.user.market_offers.find(params[:id])
    @return_card = offer.brainrot_card
    MarketOfferWithdrawer.call(user: Current.user, offer: offer)
    redirect_to return_path, notice: "Angebot zurückgezogen. Die Karte bleibt in deinem Inventar.", status: :see_other
  rescue GameplayError => error
    redirect_to return_path, alert: error.message, status: :see_other
  end

  def purchase
    offer = MarketOffer.find(params[:id])
    MarketOfferBuyer.call(buyer: Current.user, offer: offer)
    redirect_to inventory_index_path, notice: "Karte gekauft! #{offer.price} Coins wurden an den Verkäufer übertragen.", status: :see_other
  rescue GameplayError => error
    @purchase_error = error.message
    render :purchase_error, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    @purchase_error = "Dieses Angebot ist nicht mehr verfügbar."
    render :purchase_error, status: :not_found
  end

  private

  def set_card
    @card = Current.user.brainrot_cards.includes(:rank, brainrot_type: { image_attachment: :blob }).find(params[:brainrot_card_id])
    raise ActiveRecord::RecordNotFound unless BrainrotCardPolicy.new(Current.user, @card).manage?
  end

  def return_path
    return brainrot_card_path(@return_card) if params[:return_to] == "card" && @return_card

    params[:return_to] == "inventory" ? inventory_index_path : marketplace_index_path
  end
end
