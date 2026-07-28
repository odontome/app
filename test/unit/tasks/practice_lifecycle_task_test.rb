# frozen_string_literal: true

require 'test_helper'

class PracticeLifecycleTaskTest < RakeTaskTestCase
  rake_task 'odontome:practice_lifecycle'

  def setup
    super
    travel_to Time.utc(2025, 1, 15, 10, 0, 0) # 10am in Europe/London
    ActionMailer::Base.deliveries.clear

    # practices(:trialing_practice) keeps its fixture timezone of "Europe/London"
    # (the real-world IANA identifier signup produces) on purpose: practices_in_timezones
    # now expands friendly names ("London") through ActiveSupport::TimeZone::MAPPING to
    # also match IANA identifiers, so this fixture matching the 10am-local gate as-is is
    # itself the regression test for that fix.
  end

  def teardown
    travel_back
    super
  end

  def practice
    @practice ||= practices(:trialing_practice)
  end

  test 'sends activation nudge to 3-day-old practices with no patients' do
    practice.update_columns(created_at: 3.days.ago, patients_count: 0)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert practice.reload.notified_of_activation_nudge
    email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t('mailers.practice.activation_nudge.subject'), email.subject
  end

  test 'does not send activation nudge twice' do
    practice.update_columns(created_at: 3.days.ago, patients_count: 0,
                            notified_of_activation_nudge: true)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
  end

  test 'does not send activation nudge to practices with patients' do
    practice.update_columns(created_at: 3.days.ago, patients_count: 1)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
  end

  test 'does not send activation nudge outside the send window' do
    practice.update_columns(created_at: 1.day.ago, patients_count: 0)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
  end

  test 'sends trial ending notice when trial ends within 5 days' do
    practice.update_columns(created_at: 26.days.ago, patients_count: 1)
    practice.subscription.update_columns(current_period_end: 4.days.from_now)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert practice.reload.notified_of_trial_ending
    assert_equal I18n.t('mailers.practice.trial_ending.subject'),
                 ActionMailer::Base.deliveries.last.subject
  end

  test 'does not send trial ending notice to active subscriptions' do
    other = practices(:complete)
    other.subscription.update_columns(status: 'active', current_period_end: 4.days.from_now)

    @task.invoke

    refute ActionMailer::Base.deliveries.map(&:subject)
                             .include?(I18n.t('mailers.practice.trial_ending.subject'))
  end

  test 'sends trial ended notice the day after expiry' do
    practice.update_columns(created_at: 31.days.ago, patients_count: 1)
    practice.subscription.update_columns(current_period_end: 1.day.ago)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert practice.reload.notified_of_trial_ended
    assert_equal I18n.t('mailers.practice.trial_ended.subject'),
                 ActionMailer::Base.deliveries.last.subject
  end

  test 'sends deletion warning to 37-day-old practices with no patients' do
    practice.update_columns(created_at: 37.days.ago, patients_count: 0,
                            notified_of_activation_nudge: true)
    practice.subscription.update_columns(current_period_end: 7.days.ago)

    # trial_ended (window passed) must not fire; only deletion warning
    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      @task.invoke
    end

    assert practice.reload.notified_of_deletion_warning
    assert_equal I18n.t('mailers.practice.deletion_warning.subject'),
                 ActionMailer::Base.deliveries.last.subject
  end

  test 'sends nothing outside the 10am local window' do
    travel_to Time.utc(2025, 1, 15, 20, 0, 0) # 8pm in London
    practice.update_columns(created_at: 3.days.ago, patients_count: 0)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
  end

  test 'skips cancelled practices' do
    practice.update_columns(created_at: 3.days.ago, patients_count: 0,
                            cancelled_at: Time.now)

    @task.invoke

    assert_empty ActionMailer::Base.deliveries
  end

  test 'isolates a failed delivery so other eligible practices still get notified' do
    first = practice # practices(:trialing_practice)
    second = practices(:complete) # also trialing, eligible for activation nudge

    first.update_columns(created_at: 3.days.ago, patients_count: 0)
    second.update_columns(created_at: 3.days.ago, patients_count: 0)

    PracticeMailer.stub(:activation_nudge, ->(p) { raise 'boom' if p.id == first.id; PracticeMailer.welcome_email(p) }) do
      @task.invoke
    end

    refute first.reload.notified_of_activation_nudge
    assert second.reload.notified_of_activation_nudge
    assert_equal 1, ActionMailer::Base.deliveries.count
  end
end
