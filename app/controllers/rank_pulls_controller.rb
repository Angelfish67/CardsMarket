class RankPullsController < ApplicationController
  def create
    @card = Current.user.brainrot_cards.find(params[:brainrot_card_id])
    raise ActiveRecord::RecordNotFound unless BrainrotCardPolicy.new(Current.user, @card).manage?

    pull = RankPuller.call(user: Current.user, card: @card)
    redirect_to return_path,
      notice: "Rank-Pull: #{@card.brainrot_type.name} hat jetzt Rank #{pull.rank.name}. Kosten: #{pull.coins_spent} Coins.",
      status: :see_other
  rescue GameplayError => error
    redirect_to return_path, alert: error.message, status: :see_other
  end

  private

  def return_path
    params[:return_to] == "card" ? brainrot_card_path(@card) : inventory_index_path
  end
end
