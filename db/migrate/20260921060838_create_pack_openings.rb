class CreatePackOpenings < ActiveRecord::Migration[8.1]
  def change
    create_table :pack_openings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pack, null: false, foreign_key: true
      t.integer :coins_spent

      t.timestamps
    end
  end
end
