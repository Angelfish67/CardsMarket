class CreateBrainrotCards < ActiveRecord::Migration[8.1]
  def change
    create_table :brainrot_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :brainrot_type, null: false, foreign_key: true
      t.references :rank, null: false, foreign_key: true
      t.references :pack_opening, null: false, foreign_key: true

      t.timestamps
    end
  end
end
