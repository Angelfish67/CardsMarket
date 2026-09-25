class Admin::PacksController < Admin::CatalogController
  MODEL = Pack
  LABEL = "Packs"
  FIELDS = [ :name, :price, :cards_count, :active, { allowed_rarities: [] } ].freeze
end
