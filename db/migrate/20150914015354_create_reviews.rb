# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[5.0]
  def change
    create_table :reviews do |t|
      t.integer :appointment_id
      t.integer :score
      t.string :comment

      t.timestamps null: false
    end
  end
end
