class InventoryController < ApplicationController
  SORT_OPTIONS = [
    [ "Ziehdatum", "created_at" ], [ "Name", "name" ], [ "Seltenheit", "rarity" ],
    [ "Rank", "rank" ], [ "Kartenwert", "value" ]
  ].freeze

  def index
    @sort = SORT_OPTIONS.map(&:last).include?(params[:sort]) ? params[:sort] : "created_at"
    @direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
    @cards = Current.user.brainrot_cards.joins(:rank, :brainrot_type)
      .includes(:rank, brainrot_type: { image_attachment: :blob })
      .order(sort_column.public_send(@direction), BrainrotCard.arel_table[:id].desc)
    @active_offers = Current.user.market_offers.active.index_by(&:brainrot_card_id)
  end

  private

  def sort_column
    types = BrainrotType.arel_table
    ranks = Rank.arel_table

    case @sort
    when "name" then types[:name].lower
    when "rarity" then types[:rarity]
    when "value" then types[:base_value] * ranks[:multiplier]
    when "rank"
      Rank::NAMES.each_with_index.reduce(Arel::Nodes::Case.new(ranks[:name])) do |order, (name, index)|
        order.when(name).then(index)
      end.else(-1)
    else BrainrotCard.arel_table[:created_at]
    end
  end
end
