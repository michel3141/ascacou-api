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

ActiveRecord::Schema[8.1].define(version: 2026_10_24_120001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "games", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.integer "number", null: false
    t.string "status", null: false
    t.integer "host_hand", default: [], null: false, array: true
    t.integer "guest_hand", default: [], null: false, array: true
    t.bigint "first_player_id", null: false
    t.string "opening_color"
    t.boolean "takeback_requested", default: false, null: false
    t.string "result"
    t.string "end_reason"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["first_player_id"], name: "index_games_on_first_player_id"
    t.index ["room_id", "number"], name: "index_games_on_room_id_and_number", unique: true
    t.index ["room_id"], name: "index_games_on_room_id"
  end

  create_table "moves", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "rank", null: false
    t.string "coord", null: false
    t.string "color", null: false
    t.string "next_color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "coord"], name: "index_moves_on_game_id_and_coord", unique: true
    t.index ["game_id", "rank"], name: "index_moves_on_game_id_and_rank", unique: true
  end

  create_table "picks", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "rank", null: false
    t.integer "card", null: false
    t.string "hand", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "card"], name: "index_picks_on_game_id_and_card", unique: true
    t.index ["game_id", "rank"], name: "index_picks_on_game_id_and_rank", unique: true
  end

  create_table "room_presences", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "user_id", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "user_id"], name: "index_room_presences_on_room_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_room_presences_on_user_id"
  end

  create_table "room_viewers", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.string "key", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_room_viewers_on_key", unique: true
    t.index ["room_id"], name: "index_room_viewers_on_room_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.bigint "host_id", null: false
    t.bigint "guest_id"
    t.string "code", null: false
    t.string "visibility", default: "private", null: false
    t.string "status", default: "waiting", null: false
    t.string "deal_method", default: "random", null: false
    t.boolean "allow_multiple", default: false, null: false
    t.boolean "imposed_color", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["guest_id"], name: "index_rooms_on_guest_id"
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["visibility", "status"], name: "index_rooms_on_visibility_and_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "games", "rooms"
  add_foreign_key "games", "users", column: "first_player_id"
  add_foreign_key "moves", "games"
  add_foreign_key "picks", "games"
  add_foreign_key "room_presences", "rooms"
  add_foreign_key "room_presences", "users"
  add_foreign_key "room_viewers", "rooms"
  add_foreign_key "rooms", "users", column: "guest_id"
  add_foreign_key "rooms", "users", column: "host_id"
end
