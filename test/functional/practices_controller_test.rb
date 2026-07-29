# frozen_string_literal: true

require 'test_helper'

class PracticesControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  teardown do
    I18n.locale = I18n.default_locale
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
      post :create, params: { practice: practice, consent_terms: '1', consent_privacy: '1' }
    end

    welcome_email = ActionMailer::Base.deliveries.last

    assert_equal ['hello@odonto.me'], welcome_email.from
    assert_equal ['demo@odonto.me'], welcome_email.to
    assert_equal I18n.t('mailers.practice.welcome.subject'), welcome_email.subject
    assert_match(/Welcome to Odonto.me/, welcome_email.encoded)

    assert_equal @controller.session['user'].email, practice[:users_attributes]['0']['email']
    assert_redirected_to practice_path(ref: 'signup')

    # Verify consent records were created
    new_user = Practice.last.users.first
    assert UserConsent.accepted?(new_user, 'terms')
    assert UserConsent.accepted?(new_user, 'privacy')
  end

  test 'should not create practice without consent' do
    @controller.session['user'] = nil

    practice = { name: 'Odonto.me Demo Practice',
                 timezone: 'Europe/London',
                 users_attributes: { '0' => { 'email' => 'demo@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_no_difference('Practice.count') do
      post :create, params: { practice: practice }
    end
    assert_response :success
  end

  test 'should create practice with invalid timezone' do
    @controller.session['user'] = nil

    practice = { name: 'Odonto.me Demo Practice',
                 timezone: '',
                 users_attributes: { '0' => { 'email' => 'demo@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_difference('Practice.count') do
      post :create, params: { practice: practice, consent_terms: '1', consent_privacy: '1' }
    end
    assert_equal Practice.last.email, 'demo@odonto.me'
  end

  test 'signup page renders in Spanish for Spanish browsers' do
    @controller.session['user'] = nil
    @request.headers['Accept-Language'] = 'es-MX,es;q=0.9,en;q=0.8'

    get :new

    assert_response :success
    assert_equal :es, I18n.locale
  end

  test 'should create practice with locale detected from browser' do
    @controller.session['user'] = nil
    @request.headers['Accept-Language'] = 'es-MX,es;q=0.9,en;q=0.8'

    practice = { name: 'Clinica Demo',
                 timezone: 'America/Mexico_City',
                 users_attributes: { '0' => { 'email' => 'demo-es@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_difference('Practice.count') do
      post :create, params: { practice: practice, consent_terms: '1', consent_privacy: '1' }
    end

    assert_equal 'es', Practice.last.locale

    welcome_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t('mailers.practice.welcome.subject', locale: :es), welcome_email.subject
  end

  test 'should create practice with English locale for unsupported browser language' do
    @controller.session['user'] = nil
    @request.headers['Accept-Language'] = 'de-DE,de;q=0.9'

    practice = { name: 'Deutsche Praxis',
                 timezone: 'Europe/London',
                 users_attributes: { '0' => { 'email' => 'demo-de@odonto.me', 'password' => '1234567890',
                                              'password_confirmation' => '1234567890' } } }

    assert_difference('Practice.count') do
      post :create, params: { practice: practice, consent_terms: '1', consent_privacy: '1' }
    end

    assert_equal 'en', Practice.last.locale
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

  test 'settings shows trial copy with days left and price while trialing' do
    # Freeze at mid-day UTC: near midnight the practice timezone is already on
    # the next date, which shifts days_to_next_payment by one and flakes CI
    travel_to Time.utc(2026, 8, 15, 12, 0, 0) do
      users(:founder).practice.subscription.update_columns(status: 'trialing',
                                                            current_period_end: 20.days.from_now)

      get :settings

      assert_response :success
      assert_match I18n.t('subscriptions.message_to_admin.trialing_intro', days: 20), response.body
      assert_match Rails.configuration.stripe[:price_display], response.body
    end
  end

  test 'settings shows expired copy after trial ends' do
    users(:founder).practice.subscription.update_columns(status: 'trialing',
                                                          current_period_end: 1.day.ago)

    get :settings

    assert_response :success
    assert_match(/no longer active/, response.body)
  end

  test 'settings shows past due copy when payment failed' do
    users(:founder).practice.subscription.update_columns(status: 'past_due')

    get :settings

    assert_response :success
    assert_match(/update your billing details/, response.body)
  end
end
