class CreateAdminUser < ActiveRecord::Migration
  def self.up
    user = User.create!(:firstname => 'Odontome', :lastname => 'Administrator', :email => 'admin@odonto.me', :password => '123456', :password_confirmation => '123456', :roles => 'superadmin')
  end

  def self.down
    user = User.find_by_email( 'admin@odonto.me' )
    user.destroy
  end
end
