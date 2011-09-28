require 'test_helper'

class UserTest < ActiveSupport::TestCase  
  
  test "user attributes must not be empty" do
  	user = User.create
  	assert user.invalid?
  	assert user.errors[:firstname].any?
  	assert user.errors[:lastname].any?
  	assert user.errors[:email].any?
  	assert user.errors[:password].any?
  end
  
  test "user is not valid without an unique email" do	
  	user = User.new(:firstname => "Raul",
  									:lastname => "Riera",
  									:email => users(:founder).email)
  												
  	assert !user.save
  	assert_equal I18n.translate("activerecord.errors.messages.taken"), user.errors[:email][1]
  end
  
  test "user is not valid without a valid email address" do
  	user = User.new(:firstname => "Raul",
  									:lastname => "Riera",
  									:email => "notvalid@")
  												
  	assert !user.save
  	assert_equal I18n.translate("errors.messages.invalid"), user.errors[:email].join("; ")
  end
  
  test "user name should be less than 20 chars long each" do
		user = User.new(:firstname => "A really long firstname for a user IMHO",
										:lastname => "A really long lastname as well if you ask me",
										:email => "anok@email.com")
  	
  	assert !user.save
  	assert_equal I18n.translate("errors.messages.too_long", :count => 20), user.errors[:firstname].join("; ")
  	assert_equal I18n.translate("errors.messages.too_long", :count => 20), user.errors[:lastname].join("; ")
  end
  
  test "user password must be at least 4 chars long" do
  	user = users(:founder)
  	user.password = "123"
  	user.password_confirmation = "123"
  	
  	assert !user.save
  	assert_equal I18n.translate("errors.messages.too_short", :count => 4), user.errors[:password][1]
  end
    
  test "user password must be confirmed" do
  	user = User.new(:firstname => "Raul",
  									:lastname => "Riera",
  									:email => "new@email.com")
  	user.password = "123456"
  	user.password_confirmation = "111111"
  	
  	assert !user.save
  	assert_equal I18n.translate("errors.messages.confirmation"), user.errors[:password][1]
  end
	
	test "user fullname shortcut" do
		user = users(:founder)
		
		assert_equal user.fullname, "#{user.firstname} #{user.lastname}"
	end
  
end
