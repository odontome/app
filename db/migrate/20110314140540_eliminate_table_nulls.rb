class EliminateTableNulls < ActiveRecord::Migration[5.0]
  def self.up
    change_column :appointments, :practice_id, :integer, null: true
    change_column :appointments, :doctor_id, :integer, null: true
    change_column :appointments, :patient_id, :integer, null: true

    change_column :doctors, :practice_id, :integer, null: true
    change_column :doctors, :firstname, :string, null: true
    change_column :doctors, :lastname, :string, null: true

    change_column :patients, :practice_id, :integer, null: true
    change_column :patients, :firstname, :string, null: true
    change_column :patients, :lastname, :string, null: true
    change_column :patients, :date_of_birth, :date, null: true

    change_column :plans, :number_of_patients, :integer, null: true
    change_column :plans, :price, :decimal, precision: 4, scale: 2, null: true

    change_column :practices, :plan_id, :integer, default: 1, null: true

    change_column :users, :firstname, :string, null: true
    change_column :users, :lastname, :string, null: true
    change_column :users, :email, :string, null: true
    change_column :users, :crypted_password, :string, null: true
    change_column :users, :roles, :string, default: 'user', null: true
    change_column :users, :login_count, :integer, default: 0, null: true
  end

  def self.down
    change_column :appointments, :practice_id, :integer, null: false
    change_column :appointments, :doctor_id, :integer, null: false
    change_column :appointments, :patient_id, :integer, null: false

    change_column :doctors, :practice_id, :integer, null: false
    change_column :doctors, :firstname, :string, null: false
    change_column :doctors, :lastname, :string, null: false

    change_column :patients, :practice_id, :integer, null: false
    change_column :patients, :firstname, :string, null: false
    change_column :patients, :lastname, :string, null: false
    change_column :patients, :date_of_birth, :date, null: false

    change_column :plans, :number_of_patients, :integer, null: false
    change_column :plans, :price, :decimal, precision: 4, scale: 2, null: false

    change_column :practices, :plan_id, :integer, default: 1, null: false

    change_column :users, :firstname, :string, null: false
    change_column :users, :lastname, :string, null: false
    change_column :users, :email, :string, null: false
    change_column :users, :crypted_password, :string, null: false
    change_column :users, :roles, :string, default: 'user', null: false
    change_column :users, :login_count, :integer, default: 0, null: false
  end
end
