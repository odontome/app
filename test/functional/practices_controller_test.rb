require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  setup do
    @practice = practices(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:practices)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create practice" do
    assert_difference('Practice.count') do
      post :create, :practice => @practice.attributes
    end

    assert_redirected_to practice_path(assigns(:practice))
  end

  test "should show practice" do
    get :show, :id => @practice.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @practice.to_param
    assert_response :success
  end

  test "should update practice" do
    put :update, :id => @practice.to_param, :practice => @practice.attributes
    assert_redirected_to practice_path(assigns(:practice))
  end

  test "should destroy practice" do
    assert_difference('Practice.count', -1) do
      delete :destroy, :id => @practice.to_param
    end

    assert_redirected_to practices_path
  end
end
