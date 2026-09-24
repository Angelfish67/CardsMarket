class Admin::RanksController < Admin::CatalogController
  MODEL = Rank
  LABEL = "Ranks"
  FIELDS = %i[ multiplier weight ].freeze
end
