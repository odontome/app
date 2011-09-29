require 'test_helper'

class PracticeTest < ActiveSupport::TestCase

	test "practice attributes must not be empty" do
		practice = Practice.new
		practice.users << User.new
		
		assert practice.invalid?		
		assert practice.errors[:name].any?
	end
	
	test "practice is invalid without an invitation in beta" do
		$beta_mode = true
		
		practice = Practice.new
		practice.users << User.new
		
		assert practice.invalid?		
		assert practice.errors[:invitation_code].any?
	end
	
	test "practice is invalid without a valid invitation in beta" do
		$beta_mode = true
		
		practice = Practice.new(:invitation_code => "not a valid code")
		practice.users << User.new
		
		assert practice.invalid?		
		assert practice.errors[:invitation_code].any?
	end
	
	test "practice is created with a free plan as default" do		
		practice = Practice.new()
		practice.users << User.new
		
		assert practice.invalid?		
		assert_equal practice.status, "free"
	end	
	
	test "practice can be set to cancelled" do		
		practice = Practice.new()
		practice.users << User.new
		
		practice.set_as_cancelled
			
		assert_equal practice.status, "cancelled"
	end	
	
	test "practice sets the first user name" do
		practice = Practice.new()
		practice.users << User.new
		
		assert practice.invalid?		
		assert_equal practice.users.first.firstname, "Administrator"
		assert_equal practice.users.first.lastname, "User"
	end	
	
end