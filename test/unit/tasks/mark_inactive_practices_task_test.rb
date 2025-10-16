# frozen_string_literal: true

require 'test_helper'

class MarkInactivePracticesTaskTest < RakeTaskTestCase
  rake_task 'odontome:mark_inactive_practices_for_cancellation'

  test 'marks practice for cancellation when trialing for more than 60 days' do
    practice = practices(:trialing_practice)
    practice.update_columns(cancelled_at: nil)

    # Set subscription to trialing with start date > 60 days ago
    practice.subscription.update_columns(
      status: 'trialing',
      current_period_start: 61.days.ago,
      current_period_end: 31.days.ago
    )

    @task.invoke

    practice.reload
    assert_not_nil practice.cancelled_at
  end

  test 'does not mark practice when trialing for less than 60 days' do
    practice = practices(:trialing_practice)
    practice.update_columns(cancelled_at: nil)

    # Set subscription to trialing with start date < 60 days ago (recent trial)
    practice.subscription.update_columns(
      status: 'trialing',
      current_period_start: 30.days.ago,
      current_period_end: Time.now
    )

    @task.invoke

    practice.reload
    assert_nil practice.cancelled_at
  end

  test 'does not mark practice that already has active subscription' do
    practice = practices(:complete_another_language)
    practice.update_columns(cancelled_at: nil)

    # Update subscription to active status
    practice.subscription.update_columns(
      status: 'active',
      current_period_start: 61.days.ago,
      current_period_end: 31.days.ago
    )

    @task.invoke

    practice.reload
    assert_nil practice.cancelled_at
  end

  test 'does not mark practice that is already cancelled' do
    practice = practices(:canceled_practice)

    # Ensure practice is already cancelled
    practice.update_columns(cancelled_at: 30.days.ago) if practice.cancelled_at.nil?

    # Set subscription to trialing with old start date
    practice.subscription.update_columns(
      status: 'trialing',
      current_period_start: 61.days.ago,
      current_period_end: 31.days.ago
    )

    original_cancelled_at = practice.cancelled_at

    @task.invoke

    practice.reload
    assert_equal original_cancelled_at.to_i, practice.cancelled_at.to_i
  end

  test 'marks multiple practices with expired trials' do
    # Setup first practice with expired trial
    practice1 = practices(:trialing_practice)
    practice1.update_columns(cancelled_at: nil)

    practice1.subscription.update_columns(
      status: 'trialing',
      current_period_start: 61.days.ago,
      current_period_end: 31.days.ago
    )

    # Setup second practice with expired trial
    practice2 = practices(:past_due_practice)
    practice2.update_columns(cancelled_at: nil)

    practice2.subscription.update_columns(
      status: 'trialing',
      current_period_start: 70.days.ago,
      current_period_end: 40.days.ago
    )

    @task.invoke

    practice1.reload
    practice2.reload
    assert_not_nil practice1.cancelled_at
    assert_not_nil practice2.cancelled_at
  end
end
