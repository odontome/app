# frozen_string_literal: true

require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = { 'id' => users(:founder).id }
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

    # Get the created user and verify session was set correctly
    created_user = User.find(@controller.session['user']['id'])
    assert_equal created_user.email, practice[:users_attributes]['0']['email']
    assert_redirected_to practice_path
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
end
