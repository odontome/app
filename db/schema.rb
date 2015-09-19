# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150915004146) do

  create_table "appointments", force: :cascade do |t|
    t.integer  "doctor_id"
    t.integer  "patient_id"
    t.string   "notes",                limit: 255
    t.string   "status",               limit: 50
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "notified_of_reminder",             default: false
    t.integer  "datebook_id"
    t.boolean  "notified_of_schedule",             default: false
    t.boolean  "notified_of_review",               default: false
  end

  add_index "appointments", ["starts_at", "ends_at"], name: "index_appointments_on_starts_at_and_ends_at"

  create_table "balances", force: :cascade do |t|
    t.integer  "patient_id"
    t.float    "amount"
    t.string   "notes",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.string   "subject",              limit: 255
    t.string   "message",              limit: 255
    t.integer  "number_of_recipients"
    t.integer  "user_id"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.integer  "number_of_opens",                  default: 0
  end

  create_table "datebooks", force: :cascade do |t|
    t.integer  "practice_id"
    t.string   "name",        limit: 100
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.integer  "starts_at",               default: 8
    t.integer  "ends_at",                 default: 20
  end

  create_table "doctors", force: :cascade do |t|
    t.string   "uid",         limit: 255
    t.integer  "practice_id"
    t.string   "firstname",   limit: 255
    t.string   "lastname",    limit: 255
    t.string   "gender",      limit: 255
    t.boolean  "is_active",               default: true
    t.string   "speciality",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email",       limit: 255
    t.string   "color",       limit: 7,   default: "#3366CC"
  end

  create_table "notes", force: :cascade do |t|
    t.string   "notes",         limit: 500
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "noteable_id"
    t.string   "noteable_type", limit: 255
    t.integer  "user_id"
  end

  create_table "patients", force: :cascade do |t|
    t.string   "uid",                 limit: 255
    t.integer  "practice_id"
    t.string   "firstname",           limit: 255
    t.string   "lastname",            limit: 255
    t.text     "address"
    t.string   "email",               limit: 255
    t.string   "telephone",           limit: 255
    t.string   "mobile",              limit: 255
    t.string   "emergency_telephone", limit: 255
    t.date     "date_of_birth"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "allergies"
    t.text     "past_illnesses"
    t.text     "surgeries"
    t.text     "medications"
    t.string   "cigarettes_per_day",  limit: 255
    t.string   "drinks_per_day",      limit: 255
    t.text     "drugs_use"
    t.text     "family_diseases"
  end

  create_table "practices", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.string   "locale",             limit: 255, default: "en_US"
    t.string   "timezone",           limit: 255
    t.string   "status",             limit: 50,  default: "free"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "plan_id",                        default: 1
    t.datetime "cancelled_at"
    t.integer  "number_of_patients",             default: 500
    t.string   "invitation_code",    limit: 255
    t.string   "currency_unit",      limit: 255, default: "$"
    t.integer  "patients_count",                 default: 0
    t.integer  "doctors_count",                  default: 0
    t.integer  "users_count",                    default: 0
    t.integer  "datebooks_count"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer  "appointment_id"
    t.integer  "score"
    t.string   "comment"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  create_table "treatments", force: :cascade do |t|
    t.integer  "practice_id"
    t.string   "name",        limit: 100
    t.float    "price"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string   "firstname",            limit: 255
    t.string   "lastname",             limit: 255
    t.string   "email",                limit: 255
    t.string   "crypted_password",     limit: 255
    t.string   "password_salt",        limit: 255
    t.string   "persistence_token",    limit: 255
    t.string   "roles",                limit: 255, default: "user"
    t.integer  "practice_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.integer  "login_count",                      default: 0
    t.string   "perishable_token",     limit: 255, default: "",     null: false
    t.string   "authentication_token", limit: 255
    t.integer  "failed_login_count",               default: 0
    t.boolean  "subscribed_to_digest",             default: true
  end

  add_index "users", ["email"], name: "index_users_on_email"
  add_index "users", ["perishable_token"], name: "index_users_on_perishable_token"

end
