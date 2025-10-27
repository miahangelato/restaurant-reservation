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

ActiveRecord::Schema[8.0].define(version: 2025_10_27_050117) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reservations", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "time_slot_id", null: false
    t.date "reservation_date", null: false
    t.integer "num_people", null: false
    t.string "contact_name", null: false
    t.string "contact_email", null: false
    t.string "contact_phone", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "guest_token_digest"
    t.datetime "guest_token_expires_at"
    t.datetime "cancelled_at"
    t.index ["cancelled_at"], name: "index_reservations_on_cancelled_at"
    t.index ["contact_email", "reservation_date"], name: "index_reservations_on_contact_email_and_date"
    t.index ["contact_email"], name: "index_reservations_on_contact_email"
    t.index ["guest_token_digest"], name: "index_reservations_on_guest_token_digest"
    t.index ["time_slot_id"], name: "index_reservations_on_time_slot_id"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "tables", force: :cascade do |t|
    t.string "table_number", null: false
    t.integer "capacity", default: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["table_number"], name: "index_tables_on_table_number", unique: true
  end

  create_table "time_slots", force: :cascade do |t|
    t.time "time", null: false
    t.integer "max_tables", default: 10, null: false
    t.integer "max_people_per_table", default: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["time"], name: "index_time_slots_on_time", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.string "role", default: "customer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "reservations", "time_slots"
  add_foreign_key "reservations", "users"
end
