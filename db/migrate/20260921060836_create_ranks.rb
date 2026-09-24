class CreateRanks < ActiveRecord::Migration[8.1]
  def change
    create_table :ranks do |t|
      t.string :name
      t.decimal :multiplier, precision: 6, scale: 2
      t.integer :weight

      t.timestamps
    end
  end
end
