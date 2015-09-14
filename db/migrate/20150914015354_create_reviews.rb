class CreateReviews < ActiveRecord::Migration
  def change
    create_table :reviews do |t|
      t.integer :appointment_id
      t.integer :score
      t.string :comment

      t.timestamps null: false
    end
  end
end
