class CreateRankPulls < ActiveRecord::Migration[8.1]
  def change
    create_table :rank_pulls do |t|
      t.references :user, null: false, foreign_key: true
      t.references :brainrot_card, null: false, foreign_key: true
      t.references :rank, null: false, foreign_key: true
      t.integer :coins_spent

      t.timestamps
    end
  end
end
