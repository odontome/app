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

  test 'agent access only accepts active subscriptions and current trials' do
    trialing = subscriptions(:trialing)
    active = subscriptions(:active)
    past_due = subscriptions(:past_due)
    canceled = subscriptions(:canceled)

    assert trialing.grants_agent_access?
    assert active.grants_agent_access?
    assert_not past_due.grants_agent_access?
    assert_not canceled.grants_agent_access?

    trialing.update_columns(current_period_end: 1.day.ago)
    assert_not trialing.grants_agent_access?
  end

  test 'unpaid and paused subscriptions do not give access' do
    subscription = subscriptions(:active)

    %w[unpaid paused].each do |status|
      subscription.status = status

      assert_not subscription.active_or_trialing?, "#{status} gave access"
      assert_not subscription.grants_agent_access?, "#{status} gave AI app access"
    end
  end

  test 'every subscription status has a label in every locale' do
    Subscription.statuses.each_key do |status|
      %i[en es pt].each do |locale|
        assert I18n.exists?("subscriptions.status.#{status}", locale), "missing #{locale} label for #{status}"
      end
    end
  end

  test 'trial is expiring inside 7 days' do
    subscription = subscriptions(:trialing)
    subscription.update_columns(current_period_end: 6.days.from_now)

    assert subscription.is_trial_expiring?
  end

  test 'trial is not expiring outside 7 days' do
    subscription = subscriptions(:trialing)
    subscription.update_columns(current_period_end: 8.days.from_now)

    refute subscription.is_trial_expiring?
  end
end
