# frozen_string_literal: true

require 'test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  test 'trial starts ending only after 14 days' do
    subscription = subscriptions(:trialing)
    assert !subscription.is_trial_expiring?

    subscription.current_period_end = 6.days.from_now
    assert subscription.is_trial_expiring?
  end

  test 'trial ending is false if not active' do
    subscription = subscriptions(:canceled)
    assert !subscription.is_trial_expiring?
  end

  test 'trial ending is false if active' do
    subscription = subscriptions(:active)
    assert !subscription.is_trial_expiring?
  end

  test 'trial expires if past payment' do
    subscription = subscriptions(:trialing)
    assert !subscription.is_trial_expired?

    subscription.current_period_end = Date.today
    assert subscription.is_trial_expired?

    subscription.current_period_end = 2.days.ago
    assert subscription.is_trial_expired?
  end

  test 'active subscriptions include trials, past due, and active' do
    trialing = subscriptions(:trialing)
    assert trialing.active_or_trialing?

    active = subscriptions(:active)
    assert active.active_or_trialing?

    past_due = subscriptions(:past_due)
    assert past_due.active_or_trialing?
  end
end
