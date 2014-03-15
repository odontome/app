require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  
  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token
  end
  
	test "should get new" do
		controller.session["user_credentials"] = nil
	  get :new
	  assert_response :success
	end
    
  test "should show practice" do
    get :show, id: practices(:complete).to_param
    assert_response :success
  end

  test "should create practice and send welcome email" do
    controller.session["user_credentials"] = nil

    practice = { :name => "Odonto.me Demo Practice", 
                 :timezone => "Europe/London",
                 :users_attributes => {"0"=>{"email"=> "demo@odonto.me", "password"=> "1234567890", "password_confirmation"=> "1234567890" } } }

    assert_difference('Practice.count') do
      post :create, practice: practice
    end

    welcome_email = ActionMailer::Base.deliveries.last
 
    assert_equal ['hello@odonto.me'], welcome_email.from
    assert_equal ['demo@odonto.me'], welcome_email.to
    assert_equal I18n.t("mailers.practice.welcome.subject"), welcome_email.subject
    assert_match(/Hello and welcome to Odonto.me!/, welcome_email.encoded)

    assert_redirected_to practice_path
  end

  test "should create practice with invalid timezone" do
    controller.session["user_credentials"] = nil

    practice = { :name => "Odonto.me Demo Practice", 
                 :timezone => "",
                 :users_attributes => {"0"=>{"email"=> "demo@odonto.me", "password"=> "1234567890", "password_confirmation"=> "1234567890" } } }

    assert_difference('Practice.count') do
      post :create, practice: practice
    end

  end
  
end