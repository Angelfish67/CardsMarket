class AddActiveOfferOrderingIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :market_offers, [ :created_at, :id ], order: { created_at: :desc, id: :desc },
      where: "status = 0", name: "index_active_offers_by_newest", algorithm: :concurrently
  end
end
