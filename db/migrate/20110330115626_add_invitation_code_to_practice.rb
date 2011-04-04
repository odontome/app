class AddInvitationCodeToPractice < ActiveRecord::Migration
  def self.up
    change_table :practices do |t|
      t.string :invitation_code
    end
  end

  def self.down
    remove_column :practices, :invitation_code
  end
end
