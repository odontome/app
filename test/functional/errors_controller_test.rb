# frozen_string_literal: true

require 'test_helper'

class ErrorsControllerTest < ActionController::TestCase
  test '/422 routes to the unprocessable page' do
    assert_routing '/422', controller: 'errors', action: 'unprocessable'
  end

  test 'unprocessable renders with a 422 status' do
    get :unprocessable
    assert_response :unprocessable_entity
  end

  test 'not_found renders with a 404 status' do
    get :not_found
    assert_response :not_found
  end

  test 'unauthorised renders with a 401 status' do
    get :unauthorised
    assert_response :unauthorized
  end

  test 'server_error renders with a 500 status' do
    get :server_error
    assert_response :internal_server_error
  end
end
