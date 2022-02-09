# frozen_string_literal: true

require 'test_helper'

class SubscriptionsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)
  end

  test 'should be redirected to stripe when using a valid configuration' do
    post :create
    assert_redirected_to %r(\Ahttps://checkout.stripe.com/pay/)
  end
end
