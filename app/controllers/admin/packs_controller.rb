class Admin::PacksController < Admin::CatalogController
  MODEL = Pack
  LABEL = "Packs"
  FIELDS = %i[ name price cards_count active ].freeze
end
