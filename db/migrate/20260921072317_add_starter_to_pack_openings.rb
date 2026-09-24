class AddStarterToPackOpenings < ActiveRecord::Migration[8.1]
  def change
    add_column :pack_openings, :starter, :boolean, default: false, null: false

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE pack_openings SET starter = TRUE
          FROM packs WHERE pack_openings.pack_id = packs.id AND packs.starter = TRUE
        SQL
      end
    end

    add_index :pack_openings, :user_id, unique: true, where: "starter = TRUE",
      name: "index_one_starter_opening_per_user"
    add_check_constraint :pack_openings, "NOT starter OR coins_spent = 0",
      name: "starter_openings_free"
  end
end
