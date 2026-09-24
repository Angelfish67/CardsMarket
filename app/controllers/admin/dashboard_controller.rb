class Admin::DashboardController < Admin::BaseController
  def index
    @counts = { "Benutzer" => User.count, "Karten im Umlauf" => BrainrotCard.count,
      "Aktive Angebote" => MarketOffer.active.count, "Verkäufe" => MarketOffer.sold.count }
    @activities = AdminActivity.includes(:admin).order(id: :desc).limit(8)
  end
end
