class PackOpeningsController < ApplicationController
  def show
    @opening = Current.user.pack_openings.includes(:pack, brainrot_cards: [ :rank, { brainrot_type: { image_attachment: :blob } } ]).find(params[:id])
    @cards = @opening.brainrot_cards.sort_by(&:id)
  end
end
