class CreatePacks < ActiveRecord::Migration[8.1]
  def change
    create_table :packs do |t|
      t.string :name
      t.integer :price
      t.integer :cards_count
      t.boolean :starter

      t.timestamps
    end
  end
end
