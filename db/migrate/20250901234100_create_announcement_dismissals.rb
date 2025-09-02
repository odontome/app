# frozen_string_literal: true

class CreateAnnouncementDismissals < ActiveRecord::Migration[7.2]
  def change
    create_table :announcement_dismissals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :announcement, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :announcement_dismissals, [:user_id, :announcement_id], unique: true, name: 'index_announcement_dismissals_on_user_and_announcement'
  end
end