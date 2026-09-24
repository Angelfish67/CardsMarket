class EnforceMarketIntegrity < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :role, from: nil, to: 0
    change_column_default :users, :coins, from: nil, to: 1_000
    change_column_default :packs, :starter, from: nil, to: false
    change_column_default :market_offers, :status, from: nil, to: 0

    {
      users: %i[username role coins],
      brainrot_types: %i[name rarity base_value],
      ranks: %i[name multiplier weight],
      packs: %i[name price cards_count starter],
      pack_openings: %i[coins_spent],
      market_offers: %i[price status],
      rank_pulls: %i[coins_spent]
    }.each do |table, columns|
      columns.each { |column| change_column_null table, column, false }
    end

    add_reference :market_offers, :buyer, foreign_key: { to_table: :users }
    add_index :users, "lower(username)", unique: true, name: "index_users_on_normalized_username"
    add_index :users, "lower(email_address)", unique: true, name: "index_users_on_normalized_email"
    add_index :brainrot_types, :name, unique: true
    add_index :ranks, :name, unique: true
    add_index :market_offers, :brainrot_card_id, unique: true,
      where: "status = 0", name: "index_one_active_offer_per_card"
    add_index :market_offers, :status
    add_index :brainrot_types, :rarity

    add_check_constraint :users, "coins >= 0", name: "users_nonnegative_coins"
    add_check_constraint :users, "role IN (0, 1)", name: "users_valid_role"
    add_check_constraint :users, "length(trim(username)) BETWEEN 1 AND 30", name: "users_valid_username"
    add_check_constraint :brainrot_types, "base_value > 0", name: "types_positive_value"
    add_check_constraint :brainrot_types, "rarity IN (0, 1, 2, 3, 4)", name: "types_valid_rarity"
    add_check_constraint :ranks, "name IN ('E', 'D', 'C', 'B', 'A', 'SS')", name: "ranks_valid_name"
    add_check_constraint :ranks, "multiplier > 0 AND weight > 0", name: "ranks_positive_values"
    add_check_constraint :packs, "price >= 0 AND cards_count > 0", name: "packs_valid_values"
    add_check_constraint :packs, "NOT starter OR price = 0", name: "starter_packs_free"
    add_check_constraint :pack_openings, "coins_spent >= 0", name: "openings_nonnegative_cost"
    add_check_constraint :rank_pulls, "coins_spent >= 0", name: "pulls_nonnegative_cost"
    add_check_constraint :market_offers, "price > 0", name: "offers_positive_price"
    add_check_constraint :market_offers, "status IN (0, 1, 2)", name: "offers_valid_status"
    add_check_constraint :market_offers, "buyer_id IS NULL OR buyer_id <> user_id", name: "offers_no_self_purchase"
    add_check_constraint :market_offers,
      "(status = 1 AND buyer_id IS NOT NULL AND sold_at IS NOT NULL) OR " \
      "(status IN (0, 2) AND buyer_id IS NULL AND sold_at IS NULL)",
      name: "offers_sale_details_match_status"
  end
end
