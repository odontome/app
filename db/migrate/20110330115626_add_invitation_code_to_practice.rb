# frozen_string_literal: true

class AddInvitationCodeToPractice < ActiveRecord::Migration[5.0]
  def self.up
    change_table :practices do |t|
      t.string :invitation_code
    end
  end

  def self.down
    remove_column :practices, :invitation_code
  end
end
