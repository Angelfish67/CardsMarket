class AddAllowedRaritiesToPacks < ActiveRecord::Migration[8.1]
  def change
    add_column :packs, :allowed_rarities, :string, array: true,
      default: %w[common uncommon rare epic legendary], null: false
    add_check_constraint :packs,
      "cardinality(allowed_rarities) > 0 AND " \
      "allowed_rarities <@ ARRAY['common', 'uncommon', 'rare', 'epic', 'legendary']::varchar[] AND " \
      "array_position(allowed_rarities, NULL) IS NULL",
      name: "packs_allowed_rarities_valid"
  end
end
