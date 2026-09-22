# frozen_string_literal: true

require 'test_helper'

class SubscriptionsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'redirects anonymous users to sign in' do
    @controller.session['user'] = nil

    post :create

    assert_redirected_to signin_path
  end

  test 'should be redirected to stripe when using a valid configuration' do
    checkout_session = Struct.new(:url).new('https://checkout.stripe.com/c/pay/cs_test_123')

    Stripe::Checkout::Session.stub(:create, checkout_session) do
      post :create
    end

    assert_redirected_to 'https://checkout.stripe.com/c/pay/cs_test_123'
  end
end
