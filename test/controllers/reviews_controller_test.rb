require 'test_helper'

class ReviewsControllerTest < ActionController::TestCase
  setup do
  	current_user = users(:founder)
  	controller.session["user_credentials"] = users(:founder).persistence_token
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:reviews)
  end

  test "should get new when passing a valid appointment id" do
    ciphered_appointment_id = appointments(:unreviewed).ciphered_id

    get :new, :appointment_id => ciphered_appointment_id
    assert_response :success
  end

  test "should not get new when passing an invalid appointment id" do
    ciphered_appointment_id = "not-ciphered-correctly"

    get :new, :appointment_id => ciphered_appointment_id
    assert_redirected_to "http://www.odonto.me"
  end

  test "should create review" do    
    assert_difference('Review.count') do
      post :create, review: { appointment_id: appointments(:unreviewed).ciphered_id, comment: "I loved this place", score: 5 }, format: :js
    end

    assert_response :success
    #assert_redirected_to review_path(assigns(:review))
  end

end
