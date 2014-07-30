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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140622220346) do

  create_table "appointments", :force => true do |t|
    t.integer  "doctor_id"
    t.integer  "patient_id"
    t.string   "notes"
    t.string   "status",               :limit => 50
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "notified_of_reminder",               :default => false
    t.integer  "datebook_id"
    t.boolean  "notified_of_schedule",               :default => false
  end

  add_index "appointments", ["starts_at", "ends_at"], :name => "index_appointments_on_starts_at_and_ends_at"

  create_table "balances", :force => true do |t|
    t.integer   "patient_id"
    t.float     "amount"
    t.string    "notes"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "datebooks", :force => true do |t|
    t.integer  "practice_id"
    t.string   "name",        :limit => 100
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  create_table "doctors", :force => true do |t|
    t.string    "uid"
    t.integer   "practice_id"
    t.string    "firstname"
    t.string    "lastname"
    t.string    "gender"
    t.boolean   "is_active",                :default => true
    t.string    "speciality"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.string    "email"
    t.string    "color",       :limit => 7, :default => "#3366CC"
  end

  create_table "notes", :force => true do |t|
    t.string    "notes",         :limit => 500
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "noteable_id"
    t.string    "noteable_type"
    t.integer   "user_id"
  end

  create_table "patient_communications", :force => true do |t|
    t.string   "subject"
    t.string   "message"
    t.integer  "number_of_patients"
    t.integer  "user_id"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
  end

  create_table "patients", :force => true do |t|
    t.string    "uid"
    t.integer   "practice_id"
    t.string    "firstname"
    t.string    "lastname"
    t.text      "address"
    t.string    "email"
    t.string    "telephone"
    t.string    "mobile"
    t.string    "emergency_telephone"
    t.date      "date_of_birth"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.text      "allergies"
    t.text      "past_illnesses"
    t.text      "surgeries"
    t.text      "medications"
    t.string    "cigarettes_per_day"
    t.string    "drinks_per_day"
    t.text      "drugs_use"
    t.text      "family_diseases"
  end

  create_table "practices", :force => true do |t|
    t.string   "name"
    t.string   "locale",                           :default => "en_US"
    t.string   "timezone"
    t.string   "status",             :limit => 50, :default => "free"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "plan_id",                          :default => 1
    t.datetime "cancelled_at"
    t.integer  "number_of_patients",               :default => 500
    t.string   "invitation_code"
    t.string   "currency_unit",                    :default => "$"
    t.integer  "patients_count",                   :default => 0
    t.integer  "doctors_count",                    :default => 0
    t.integer  "users_count",                      :default => 0
    t.integer  "datebooks_count"
  end

  create_table "treatments", :force => true do |t|
    t.integer   "practice_id"
    t.string    "name",        :limit => 100
    t.float     "price"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string    "firstname"
    t.string    "lastname"
    t.string    "email"
    t.string    "crypted_password"
    t.string    "password_salt"
    t.string    "persistence_token"
    t.string    "roles",                :default => "user"
    t.integer   "practice_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.timestamp "current_login_at"
    t.timestamp "last_login_at"
    t.integer   "login_count",          :default => 0
    t.string    "perishable_token",     :default => "",     :null => false
    t.string    "authentication_token"
  end

  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["perishable_token"], :name => "index_users_on_perishable_token"

end
