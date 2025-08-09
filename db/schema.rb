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

ActiveRecord::Schema[7.2].define(version: 2025_08_09_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", id: :serial, force: :cascade do |t|
    t.integer "doctor_id"
    t.integer "patient_id"
    t.string "notes", limit: 255
    t.string "status", default: "confirmed"
    t.datetime "starts_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "notified_of_reminder", default: false
    t.integer "datebook_id"
    t.boolean "notified_of_schedule", default: false
    t.boolean "notified_of_review", default: false
    t.index ["starts_at", "ends_at"], name: "index_appointments_on_starts_at_and_ends_at"
  end

  create_table "balances", id: :serial, force: :cascade do |t|
    t.integer "patient_id"
    t.float "amount"
    t.string "notes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "datebooks", id: :serial, force: :cascade do |t|
    t.integer "practice_id"
    t.string "name", limit: 100
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "starts_at", default: 8
    t.integer "ends_at", default: 20
  end

  create_table "doctors", id: :serial, force: :cascade do |t|
    t.string "uid"
    t.integer "practice_id"
    t.string "firstname"
    t.string "lastname"
    t.string "gender"
    t.boolean "is_active", default: true
    t.string "speciality"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "email"
    t.string "color", limit: 7, default: "#3366CC"
  end

  create_table "notes", id: :serial, force: :cascade do |t|
    t.string "notes", limit: 500
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "noteable_type"
    t.integer "noteable_id"
    t.integer "user_id"
    t.index ["noteable_type", "noteable_id"], name: "index_notes_on_noteable_type_and_noteable_id"
  end

  create_table "patients", id: :serial, force: :cascade do |t|
    t.string "uid"
    t.integer "practice_id"
    t.string "firstname"
    t.string "lastname"
    t.text "address"
    t.string "email"
    t.string "telephone"
    t.string "mobile"
    t.string "emergency_telephone"
    t.date "date_of_birth"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "allergies"
    t.text "past_illnesses"
    t.text "surgeries"
    t.text "medications"
    t.string "cigarettes_per_day"
    t.string "drinks_per_day"
    t.text "drugs_use"
    t.text "family_diseases"
    t.boolean "notified_of_six_month_reminder", default: false, null: false
  end

  create_table "practices", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "locale", default: "en_US"
    t.string "timezone", default: "UTC"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "cancelled_at", precision: nil
    t.string "currency_unit", default: "$"
    t.integer "patients_count", default: 0
    t.integer "doctors_count", default: 0
    t.integer "users_count", default: 0
    t.integer "datebooks_count"
    t.string "email"
    t.text "stripe_customer_id"
  end

  create_table "reviews", id: :serial, force: :cascade do |t|
    t.integer "appointment_id"
    t.integer "score"
    t.string "comment"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "practice_id", null: false
    t.text "status", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "current_period_start", precision: nil, null: false
    t.datetime "current_period_end", precision: nil, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["practice_id"], name: "index_subscriptions_on_practice_id"
  end

  create_table "treatments", id: :serial, force: :cascade do |t|
    t.integer "practice_id"
    t.string "name", limit: 100
    t.float "price"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.string "email"
    t.string "roles", default: "user"
    t.integer "practice_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "current_login_at", precision: nil
    t.datetime "last_login_at", precision: nil
    t.string "perishable_token", default: "", null: false
    t.integer "failed_login_count", default: 0
    t.boolean "subscribed_to_digest", default: true
    t.string "password_digest"
    t.string "remember_token"
    t.datetime "remember_token_expires_at"
    t.index ["perishable_token"], name: "index_users_on_perishable_token"
    t.index ["remember_token"], name: "index_users_on_remember_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "subscriptions", "practices"
end
