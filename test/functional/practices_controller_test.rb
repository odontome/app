# frozen_string_literal: true

require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should get new' do
    @controller.session['user'] = nil
    get :new
    assert_response :success
  end

  test 'should show practice' do
    get :show, params: { id: practices(:complete).to_param }
    assert_response :success
  end

  test 'should create practice, authenticate user, and send welcome email' do
    @controller.session['user'] = nil

    practice = { name: 'Odonto.me Demo Practice',
                 timezone: 'Europe/London',
                 users_attributes: { '0' => { 'email' => 'demo@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_difference('Practice.count') do
      post :create, params: { practice: practice }
    end

    welcome_email = ActionMailer::Base.deliveries.last

    assert_equal ['hello@odonto.me'], welcome_email.from
    assert_equal ['demo@odonto.me'], welcome_email.to
    assert_equal I18n.t('mailers.practice.welcome.subject'), welcome_email.subject
    assert_match(/Welcome to Odonto.me/, welcome_email.encoded)

    assert_equal @controller.session['user'].email, practice[:users_attributes]['0']['email']
    assert_redirected_to practice_path(ref: 'signup')
  end

  test 'should create practice with invalid timezone' do
    @controller.session['user'] = nil

    practice = { name: 'Odonto.me Demo Practice',
                 timezone: '',
                 users_attributes: { '0' => { 'email' => 'demo@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_difference('Practice.count') do
      post :create, params: { practice: practice }
    end
    assert_equal Practice.last.email, 'demo@odonto.me'
  end

  test 'should update practice with custom review URL' do
    practice = practices(:complete)
    @controller.session['user'] = practice.users.first
    custom_url = 'https://custom.example.com/reviews'

    # Only send the field we intend to update; controller should not trigger unrelated validations

    put :update, params: { id: practice.id, practice: { custom_review_url: custom_url } }

    assert_response :redirect
    assert_redirected_to practice_settings_url

    practice.reload
    assert_equal custom_url, practice.custom_review_url
  end

  test 'should update practice with blank custom review URL' do
    practice = practices(:complete)
    # Set initial value
    practice.update!(custom_review_url: 'https://old.example.com')
    @controller.session['user'] = practice.users.first

    # Only send the field we intend to update; controller should not trigger unrelated validations
    put :update, params: { id: practice.id, practice: { custom_review_url: '' } }

    assert_response :redirect
    assert_redirected_to practice_settings_url

    practice.reload
    assert_equal '', practice.custom_review_url
  end

  test 'should not update practice with invalid custom review URL' do
    practice = practices(:complete)
    @controller.session['user'] = practice.users.first

    # Only send the field we intend to update; controller should not trigger unrelated validations
    put :update, params: { id: practice.id, practice: { custom_review_url: 'not-a-url' } }

    assert_response :success # Should render settings template with errors
    practice.reload
    assert_nil practice.custom_review_url
  end

  test 'should get balance page for logged in admin user' do
    get :balance
    assert_response :success
    assert_not_nil assigns(:balances)
    assert_not_nil assigns(:min_date)
    assert_not_nil assigns(:max_date)
  end

  test 'should get appointments page for logged in admin user' do
    get :appointments
    assert_response :success
    assert_not_nil assigns(:appointments)
    assert_not_nil assigns(:min_date)
    assert_not_nil assigns(:max_date)
    assert_not_nil assigns(:range_label)
  end

  test 'should redirect balance when not logged in' do
    @controller.session['user'] = nil
    get :balance
    assert_response :redirect
    assert_redirected_to signin_path
  end

  test 'should redirect appointments when not logged in' do
    @controller.session['user'] = nil
    get :appointments
    assert_response :redirect
    assert_redirected_to signin_path
  end

  test 'should redirect cancel when not logged in' do
    @controller.session['user'] = nil
    get :cancel
    assert_response :redirect
    assert_redirected_to signin_path
  end

  test 'should redirect settings when not logged in' do
    @controller.session['user'] = nil
    get :settings
    assert_response :redirect
    assert_redirected_to signin_path
  end

  test 'should redirect show when not logged in' do
    @controller.session['user'] = nil
    get :show, params: { id: practices(:complete).to_param }
    assert_response :redirect
    assert_redirected_to signin_path
  end
end
