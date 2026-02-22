# frozen_string_literal: true

require 'test_helper'

class ConsentsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should redirect to root when consent is current' do
    get :review
    assert_redirected_to root_path
  end

  test 'should show review page when terms consent is outdated' do
    # Remove the current terms consent to simulate outdated consent
    UserConsent.where(user: users(:founder), consent_type: 'terms').delete_all

    get :review
    assert_response :success
    assert assigns(:needs_terms)
  end

  test 'should show review page when privacy consent is outdated' do
    UserConsent.where(user: users(:founder), consent_type: 'privacy').delete_all

    get :review
    assert_response :success
    assert assigns(:needs_privacy)
  end

  test 'should accept terms and privacy consent' do
    UserConsent.where(user: users(:founder), consent_type: 'terms').delete_all
    UserConsent.where(user: users(:founder), consent_type: 'privacy').delete_all

    assert_difference('UserConsent.count', 2) do
      post :accept, params: { consent_terms: '1', consent_privacy: '1' }
    end

    assert_redirected_to root_path
    assert users(:founder).reload.accepted_current_terms?
    assert users(:founder).accepted_current_privacy?
  end

  test 'should redirect back to review when consent not fully accepted' do
    UserConsent.where(user: users(:founder), consent_type: 'terms').delete_all
    UserConsent.where(user: users(:founder), consent_type: 'privacy').delete_all

    post :accept, params: { consent_terms: '1' }

    assert_redirected_to consent_review_path
  end

  test 'should require login' do
    @controller.session['user'] = nil
    get :review
    assert_redirected_to signin_path
  end

  test 'should not create duplicate consent records' do
    # User already has current consent
    assert_no_difference('UserConsent.count') do
      post :accept, params: { consent_terms: '1', consent_privacy: '1' }
    end
    assert_redirected_to root_path
  end
end
