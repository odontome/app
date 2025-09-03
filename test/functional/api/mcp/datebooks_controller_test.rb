# frozen_string_literal: true

require 'test_helper'

class Api::Mcp::DatabooksControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get index' do
    get :index, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
  end

  test 'should show datebook' do
    get :show, params: { id: datebooks(:main).id }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal datebooks(:main).id, json_response['id']
  end

  test 'should create datebook' do
    datebook_params = {
      name: 'Test Datebook',
      starts_at: 8,
      ends_at: 18
    }

    assert_difference 'Datebook.count' do
      post :create, params: { datebook: datebook_params }, format: :json
    end
    assert_response :created
  end

  test 'should update datebook' do
    patch :update, params: { 
      id: datebooks(:main).id, 
      datebook: { name: 'Updated Datebook' } 
    }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'Updated Datebook', json_response['name']
  end

  test 'should destroy datebook without appointments' do
    # Create a new datebook without appointments
    datebook = Datebook.create!(
      name: 'Empty Datebook',
      practice_id: users(:founder).practice_id,
      starts_at: 8,
      ends_at: 18
    )

    assert_difference 'Datebook.count', -1 do
      delete :destroy, params: { id: datebook.id }, format: :json
    end
    assert_response :no_content
  end

  test 'should not destroy datebook with appointments' do
    delete :destroy, params: { id: datebooks(:main).id }, format: :json
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_match(/appointments/, json_response['error'])
  end

  test 'should not show datebook from different practice' do
    @controller.session['user'] = users(:other_practice)
    
    get :show, params: { id: datebooks(:main).id }, format: :json
    assert_response :not_found
  end

  test 'should require authentication' do
    @controller.session['user'] = nil
    
    get :index, format: :json
    assert_response :redirect
  end
end