require 'test_helper'

class BalancesControllerTest < ActionController::TestCase
  
  setup do
  	UserSession.create users(:founder)
  	
  	@balance = { :amount => 9.99, :patient_id => 1 }
  end
  
end