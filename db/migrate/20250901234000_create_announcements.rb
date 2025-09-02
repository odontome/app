# frozen_string_literal: true

class CreateAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :announcements do |t|
      t.integer :version, null: false
      t.string :announcement_type, null: false, default: 'info'
      t.string :i18n_key, null: false
      t.boolean :active, null: false, default: true
      t.datetime :published_at
      
      t.timestamps
    end
    
    add_index :announcements, :version, unique: true
    add_index :announcements, :active
    add_index :announcements, :published_at
  end
end