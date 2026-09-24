class MarketplaceController < ApplicationController
  PAGE_SIZE = 24

  def index
    @query = params[:q].to_s.strip.first(100)
    @rarity = BrainrotType.rarities.key?(params[:rarity]) ? params[:rarity] : ""
    @rank = Rank::NAMES.include?(params[:rank]) ? params[:rank] : ""
    @filter_params = { q: @query, rarity: @rarity, rank: @rank }.compact_blank
    @page = (Integer(params[:page], exception: false) || 1).clamp(1, 100_000)

    scope = MarketOffer.active.joins(brainrot_card: [ :brainrot_type, :rank ])
    scope = scope.where("brainrot_types.name ILIKE ?", "%#{BrainrotType.sanitize_sql_like(@query)}%") if @query.present?
    scope = scope.where(brainrot_types: { rarity: BrainrotType.rarities.fetch(@rarity) }) if @rarity.present?
    scope = scope.where(ranks: { name: @rank }) if @rank.present?
    offers = scope.includes(:user, brainrot_card: [ :rank, { brainrot_type: { image_attachment: :blob } } ])
      .order(created_at: :desc, id: :desc).offset((@page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
    @has_next_page = offers.size > PAGE_SIZE
    @offers = offers.first(PAGE_SIZE)
  end
end
