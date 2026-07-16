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

ActiveRecord::Schema[8.1].define(version: 2026_07_14_083726) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.string "name"
    t.integer "package_id"
    t.integer "status"
    t.date "time_slot"
    t.datetime "updated_at", null: false
  end

  create_table "packages", force: :cascade do |t|
    t.jsonb "core", default: {}
    t.datetime "created_at", null: false
    t.integer "duration"
    t.jsonb "extra", default: {}
    t.text "for_whom"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["core"], name: "index_packages_on_core", using: :gin
    t.index ["extra"], name: "index_packages_on_extra", using: :gin
  end

  create_table "products", force: :cascade do |t|
    t.integer "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "kind"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
