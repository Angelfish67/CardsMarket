# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_25_072535) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_activities", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_admin_activities_on_admin_id"
    t.index ["created_at"], name: "index_admin_activities_on_created_at"
  end

  create_table "brainrot_cards", force: :cascade do |t|
    t.bigint "brainrot_type_id", null: false
    t.datetime "created_at", null: false
    t.bigint "pack_opening_id", null: false
    t.bigint "rank_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["brainrot_type_id"], name: "index_brainrot_cards_on_brainrot_type_id"
    t.index ["pack_opening_id"], name: "index_brainrot_cards_on_pack_opening_id"
    t.index ["rank_id"], name: "index_brainrot_cards_on_rank_id"
    t.index ["user_id"], name: "index_brainrot_cards_on_user_id"
  end

  create_table "brainrot_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "base_value", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "name", null: false
    t.integer "rarity", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_brainrot_types_on_name", unique: true
    t.index ["rarity"], name: "index_brainrot_types_on_rarity"
    t.check_constraint "base_value > 0", name: "types_positive_value"
    t.check_constraint "rarity = ANY (ARRAY[0, 1, 2, 3, 4])", name: "types_valid_rarity"
  end

  create_table "market_offers", force: :cascade do |t|
    t.bigint "brainrot_card_id", null: false
    t.bigint "buyer_id"
    t.datetime "created_at", null: false
    t.integer "price", null: false
    t.datetime "sold_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["brainrot_card_id"], name: "index_market_offers_on_brainrot_card_id"
    t.index ["brainrot_card_id"], name: "index_one_active_offer_per_card", unique: true, where: "(status = 0)"
    t.index ["buyer_id"], name: "index_market_offers_on_buyer_id"
    t.index ["created_at", "id"], name: "index_active_offers_by_newest", order: :desc, where: "(status = 0)"
    t.index ["status"], name: "index_market_offers_on_status"
    t.index ["user_id"], name: "index_market_offers_on_user_id"
    t.check_constraint "buyer_id IS NULL OR buyer_id <> user_id", name: "offers_no_self_purchase"
    t.check_constraint "price > 0", name: "offers_positive_price"
    t.check_constraint "status = 1 AND buyer_id IS NOT NULL AND sold_at IS NOT NULL OR (status = ANY (ARRAY[0, 2])) AND buyer_id IS NULL AND sold_at IS NULL", name: "offers_sale_details_match_status"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "offers_valid_status"
  end

  create_table "pack_openings", force: :cascade do |t|
    t.integer "coins_spent", null: false
    t.datetime "created_at", null: false
    t.bigint "pack_id", null: false
    t.boolean "starter", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["pack_id"], name: "index_pack_openings_on_pack_id"
    t.index ["user_id"], name: "index_one_starter_opening_per_user", unique: true, where: "(starter = true)"
    t.index ["user_id"], name: "index_pack_openings_on_user_id"
    t.check_constraint "NOT starter OR coins_spent = 0", name: "starter_openings_free"
    t.check_constraint "coins_spent >= 0", name: "openings_nonnegative_cost"
  end

  create_table "packs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "allowed_rarities", default: ["common", "uncommon", "rare", "epic", "legendary"], null: false, array: true
    t.integer "cards_count", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "price", null: false
    t.boolean "starter", default: false, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "NOT starter OR price = 0", name: "starter_packs_free"
    t.check_constraint "cardinality(allowed_rarities) > 0 AND allowed_rarities <@ ARRAY['common'::character varying, 'uncommon'::character varying, 'rare'::character varying, 'epic'::character varying, 'legendary'::character varying] AND array_position(allowed_rarities, NULL::character varying) IS NULL", name: "packs_allowed_rarities_valid"
    t.check_constraint "price >= 0 AND cards_count > 0", name: "packs_valid_values"
  end

  create_table "rank_pulls", force: :cascade do |t|
    t.bigint "brainrot_card_id", null: false
    t.integer "coins_spent", null: false
    t.datetime "created_at", null: false
    t.bigint "rank_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["brainrot_card_id"], name: "index_rank_pulls_on_brainrot_card_id"
    t.index ["rank_id"], name: "index_rank_pulls_on_rank_id"
    t.index ["user_id"], name: "index_rank_pulls_on_user_id"
    t.check_constraint "coins_spent >= 0", name: "pulls_nonnegative_cost"
  end

  create_table "ranks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "multiplier", precision: 6, scale: 2, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", null: false
    t.index ["name"], name: "index_ranks_on_name", unique: true
    t.check_constraint "multiplier > 0::numeric AND weight > 0", name: "ranks_positive_values"
    t.check_constraint "name::text = ANY (ARRAY['E'::character varying, 'D'::character varying, 'C'::character varying, 'B'::character varying, 'A'::character varying, 'SS'::character varying]::text[])", name: "ranks_valid_name"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "coins", default: 1000, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "starter_pack_opened_at"
    t.boolean "suspended", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index "lower((email_address)::text)", name: "index_users_on_normalized_email", unique: true
    t.index "lower((username)::text)", name: "index_users_on_normalized_username", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "coins >= 0", name: "users_nonnegative_coins"
    t.check_constraint "length(TRIM(BOTH FROM username)) >= 1 AND length(TRIM(BOTH FROM username)) <= 30", name: "users_valid_username"
    t.check_constraint "role = ANY (ARRAY[0, 1])", name: "users_valid_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_activities", "users", column: "admin_id"
  add_foreign_key "brainrot_cards", "brainrot_types"
  add_foreign_key "brainrot_cards", "pack_openings"
  add_foreign_key "brainrot_cards", "ranks"
  add_foreign_key "brainrot_cards", "users"
  add_foreign_key "market_offers", "brainrot_cards"
  add_foreign_key "market_offers", "users"
  add_foreign_key "market_offers", "users", column: "buyer_id"
  add_foreign_key "pack_openings", "packs"
  add_foreign_key "pack_openings", "users"
  add_foreign_key "rank_pulls", "brainrot_cards"
  add_foreign_key "rank_pulls", "ranks"
  add_foreign_key "rank_pulls", "users"
  add_foreign_key "sessions", "users"
end
