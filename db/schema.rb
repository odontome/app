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

ActiveRecord::Schema.define(:version => 20110301165436) do

  create_table "doctors", :force => true do |t|
    t.integer  "uid"
    t.integer  "practice_id",                   :null => false
    t.string   "firstname",                     :null => false
    t.string   "lastname",                      :null => false
    t.string   "gender"
    t.boolean  "is_active",   :default => true
    t.string   "speciality"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "email"
  end

  create_table "patients", :force => true do |t|
    t.integer  "uid"
    t.integer  "practice_id",         :null => false
    t.string   "firstname",           :null => false
    t.string   "lastname",            :null => false
    t.text     "address"
    t.string   "email"
    t.string   "telephone"
    t.string   "mobile"
    t.string   "emergency_telephone"
    t.datetime "date_of_birth",       :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "allergies"
    t.text     "past_illnesses"
    t.text     "surgeries"
    t.text     "medications"
    t.string   "cigarettes_per_day"
    t.string   "drinks_per_day"
    t.text     "drugs_use"
    t.text     "family_diseases"
  end

  create_table "practices", :force => true do |t|
    t.string   "name"
    t.string   "locale",     :default => "en_US"
    t.string   "timezone"
    t.string   "status",     :default => "unconfirmed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "firstname",                             :null => false
    t.string   "lastname",                              :null => false
    t.string   "email",                                 :null => false
    t.string   "crypted_password",                      :null => false
    t.string   "password_salt"
    t.string   "persistence_token"
    t.string   "roles",             :default => "user", :null => false
    t.integer  "practice_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.integer  "login_count",       :default => 0,      :null => false
  end

end
