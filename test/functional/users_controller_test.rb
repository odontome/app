# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)

    @new_user = { firstname: 'Rebecca',
                  lastname: 'Riera',
                  email: 'rebeccariera@bokanova.mx',
                  password: '12345678',
                  password_confirmation: '12345678' }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create user' do
    assert_difference('User.count') do
      post :create, params: { user: @new_user }
    end
    assert_redirected_to users_url
  end

  test 'should show user' do
    get :show, params: { id: users(:founder).to_param }
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: users(:founder).to_param }
    assert_response :success
  end

  test 'should update user' do
    put :update, params: { id: users(:founder).to_param, user: @new_user }
    assert_redirected_to user_url
  end

  test 'should not allow a non-admin to update an admin' do
    @controller.session['user'] = users(:perishable)
    admin = users(:founder)

    put :update, params: { id: admin.to_param, user: { firstname: 'Hacked' } }

    assert_not_equal 'Hacked', admin.reload.firstname
    assert_redirected_to '/401'
  end

  test 'should destroy user' do
    assert_difference('User.count', -1) do
      delete :destroy, params: { id: users(:perishable).to_param }
    end

    assert_redirected_to users_path
  end

  test 'admin cannot delete their own account' do
    assert_no_difference('User.count') do
      delete :destroy, params: { id: users(:founder).to_param }
    end

    assert_redirected_to users_path
    assert_equal I18n.t(:user_deleted_admin_error_message), flash[:alert]
  end

  test 'changing your own password keeps you signed in on this device' do
    founder = users(:founder)
    founder.update_columns(session_token: 'old-token')
    @controller.session['user'] = { 'id' => founder.id, 'session_token' => 'old-token' }

    put :update, params: { id: founder.to_param, user: { password: 'brand-new-pass', password_confirmation: 'brand-new-pass' } }

    assert_redirected_to user_url(founder)
    assert_not_equal 'old-token', founder.reload.session_token
    assert_equal founder.session_token, @controller.session['user']['session_token']
  end

  test 'an admin changing a teammate password signs that teammate out' do
    teammate = users(:perishable)
    teammate.update_columns(session_token: 'old-token', email: 'teammate@bokanova.mx')

    put :update, params: { id: teammate.to_param, user: { password: 'brand-new-pass', password_confirmation: 'brand-new-pass' } }

    assert_not_equal 'old-token', teammate.reload.session_token
    # The admin's own session is left alone
    assert_equal users(:founder).id, @controller.session['user']['id']
  end
end
