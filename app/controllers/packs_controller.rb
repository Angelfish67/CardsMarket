class PacksController < ApplicationController
  def index
    @rarity_chances = WeightedBrainrotDraw.chances(rarities: BrainrotType.active.distinct.pluck(:rarity))
    @packs = Pack.active.order(starter: :desc, price: :asc)
    @starter_opened = !Current.user.starter_pack_pending?
  end

  def open
    pack = Pack.find(params[:id])
    opening = PackOpener.call(user: Current.user, pack: pack)
    redirect_to pack_opening_path(opening), status: :see_other
  rescue GameplayError => error
    redirect_to packs_index_path, alert: error.message, status: :see_other
  end
end
