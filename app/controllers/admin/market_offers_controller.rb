class Admin::MarketOffersController < Admin::BaseController
  def index
    @offers = paginate(MarketOffer.active.includes(:user, brainrot_card: :brainrot_type).order(id: :desc))
  end

  def destroy
    offer = MarketOffer.find(params[:id])
    Admin::Mutation.call(actor: Current.user, record: offer, action: "moderate") do
      MarketOfferWithdrawer.call(user: offer.user, offer: offer)
    end
    redirect_to admin_market_offers_path, notice: "Angebot entfernt. Die Karte bleibt beim Besitzer.", status: :see_other
  rescue GameplayError => error
    redirect_to admin_market_offers_path, alert: error.message, status: :see_other
  end
end
