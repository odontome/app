# frozen_string_literal: true

require 'test_helper'

class DatebooksControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
    @datebook = { name: 'Bokanova Dental' }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:datebooks)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should not get new if not admin' do
    @controller.session['user'] = users(:perishable)

    get :new
    assert_response :redirect
  end

  test 'should create datebook' do
    assert_difference('Datebook.count') do
      post :create, params: { datebook: @datebook }
    end
    assert_redirected_to datebooks_url
  end

  test 'should show datebook' do
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
  end

  test 'should detect iPad as mobile device' do
    @request.user_agent = 'Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X) AppleWebKit/605.1.15'
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
    assert_not_nil assigns(:is_mobile), 'iPad should be detected as mobile device'
  end

  test 'should detect iPhone as mobile device' do
    @request.user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15'
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
    assert_not_nil assigns(:is_mobile), 'iPhone should be detected as mobile device'
  end

  test 'should detect Android as mobile device' do
    @request.user_agent = 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
    assert_not_nil assigns(:is_mobile), 'Android should be detected as mobile device'
  end

  test 'should not detect desktop as mobile device' do
    @request.user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    get :show, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
    assert_nil assigns(:is_mobile), 'Desktop should not be detected as mobile device'
  end

  test 'should get edit' do
    get :edit, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :success
  end

  test 'should not get edit if not admin' do
    @controller.session['user'] = users(:perishable)

    get :edit, params: { id: datebooks(:playa_del_carmen).to_param }
    assert_response :redirect
  end

  test 'should update datebook' do
    put :update, params: { id: datebooks(:playa_del_carmen).to_param, datebook: @datebook }
    assert_redirected_to datebooks_url
  end

  test 'should destroy datebook without appointments' do
    assert_difference('Datebook.count', -1) do
      delete :destroy, params: { id: datebooks(:without_appointments).to_param }
    end

    assert_redirected_to datebooks_url
  end

  # test "should not destroy datebook with appointments" do
  #   assert_no_difference('Datebook.count') do
  #     delete :destroy, params: {id: datebooks(:playa_del_carmen).to_param}
  #   end

  #   assert_redirected_to datebooks_url
  # end
end
