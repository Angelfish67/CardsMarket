class CreateBrainrotTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :brainrot_types do |t|
      t.string :name
      t.text :description
      t.integer :rarity
      t.integer :base_value
      t.string :image_url

      t.timestamps
    end
  end
end
