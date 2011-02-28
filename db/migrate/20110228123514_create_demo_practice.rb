class CreateDemoPractice < ActiveRecord::Migration
  def self.up
    practice = Practice.create!(:name => "Odontome Demo Practice", :status => "active")
    user = User.create!(:firstname => 'Demo', :lastname => 'User', :email => 'demo@odonto.me', :password => '123456', :password_confirmation => '123456', :roles => 'admin', :practice_id => 1)
  end

  def self.down
    user = User.find_by_email('demo@odonto.me')
    practice = Practice.find(1)
    user.destroy
    practice.destroy
  end
end
