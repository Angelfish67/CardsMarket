class CreateMarketOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :market_offers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :brainrot_card, null: false, foreign_key: true
      t.integer :price
      t.integer :status
      t.datetime :sold_at

      t.timestamps
    end
  end
end
