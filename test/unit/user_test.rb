require 'test_helper'

class UserTest < ActiveSupport::TestCase  
  
  test "user attributes must not be empty" do
  	user = User.new
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
  	assert_equal I18n.t("errors.messages.taken"), user.errors[:email].first
  end
  
  test "user is not valid without a valid email address" do
  	user = User.new(:firstname => "Raul",
  									:lastname => "Riera",
  									:email => "notvalid@")
  												
  	assert !user.save
  	assert_equal I18n.t("errors.messages.invalid"), user.errors[:email].first
  end
  
  test "user name should be less than 20 chars long each" do
		user = User.new(:firstname => "A really long firstname for a user IMHO",
										:lastname => "A really long lastname as well if you ask me",
										:email => "anok@email.com")
  	
  	assert !user.save
  	assert_equal I18n.t("errors.messages.too_long", :count => 20), user.errors[:firstname].first
  	assert_equal I18n.t("errors.messages.too_long", :count => 20), user.errors[:lastname].first
  end
  
  test "user password must be at least 7 chars long" do
  	user = users(:founder)
  	user.password = "123"
    user.password_confirmation = "123"
  	
  	assert !user.save
  	assert_equal I18n.t("errors.messages.too_short", :count => 7), user.errors[:password].first
  end
    
  test "user password must be confirmed" do
  	user = User.new(:firstname => "Raul",
  									:lastname => "Riera",
  									:email => "new@email.com")
  	user.password = "1234567890"
  	user.password_confirmation = "1111111111"
  	
  	assert !user.save
  	assert_equal I18n.t("errors.messages.confirmation", attribute: 'Password'), user.errors[:password_confirmation].first
  end
	
	test "user fullname shortcut" do
		user = users(:founder)
		
		assert_equal user.fullname, "#{user.firstname} #{user.lastname}"
	end

	# FIXME: remove all of this, we are not going to use the API anymore
#   test "user authentication token changes when the password is updated" do
#     user = users(:api_user)
#     initial_token = user.authentication_token

#     user.password = "3245435436577"
#     user.password_confirmation = user.password

#     assert user.save
#     assert_not_equal initial_token, user.authentication_token
#   end
 
end
