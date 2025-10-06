# frozen_string_literal: true

require 'test_helper'
require 'rake'

class MarkInactivePracticesTaskTest < ActiveSupport::TestCase
  def setup
    @app = Rails.application
    @app.load_tasks if Rake::Task.tasks.empty?
    @task = Rake::Task['odontome:mark_inactive_practices_for_cancellation']
  end

  def teardown
    @task&.reenable
  end

  test 'marks practice for cancellation when no user has logged in for more than 60 days' do
    practice = practices(:trialing_practice)
    practice.update_columns(cancelled_at: nil)

    # Create a user for this practice with old login date
    user = User.create!(
      practice_id: practice.id,
      firstname: 'Inactive',
      lastname: 'User',
      email: 'inactive@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 61.days.ago,
      last_login_at: 62.days.ago
    )

    @task.invoke

    practice.reload
    assert_not_nil practice.cancelled_at
  end

  test 'does not mark practice when a user has logged in recently' do
    practice = practices(:trialing_practice)
    practice.update_columns(cancelled_at: nil)

    # Create a user with recent login
    user = User.create!(
      practice_id: practice.id,
      firstname: 'Active',
      lastname: 'User',
      email: 'active@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 30.days.ago,
      last_login_at: 31.days.ago
    )

    @task.invoke

    practice.reload
    assert_nil practice.cancelled_at
  end

  test 'does not mark practice that already has active subscription' do
    practice = practices(:complete_another_language)
    practice.update_columns(cancelled_at: nil)

    # Update subscription to active status
    practice.subscription.update_columns(status: 'active')

    # Create a user with old login
    User.where(practice_id: practice.id).destroy_all
    user = User.create!(
      practice_id: practice.id,
      firstname: 'Old',
      lastname: 'User',
      email: 'old@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 61.days.ago,
      last_login_at: 62.days.ago
    )

    @task.invoke

    practice.reload
    assert_nil practice.cancelled_at
  end

  test 'does not mark practice that is already cancelled' do
    practice = practices(:canceled_practice)

    # Ensure practice is already cancelled
    practice.update_columns(cancelled_at: 30.days.ago) if practice.cancelled_at.nil?

    # Create a user with old login
    User.where(practice_id: practice.id).destroy_all
    user = User.create!(
      practice_id: practice.id,
      firstname: 'Old',
      lastname: 'User',
      email: 'oldcancelled@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 61.days.ago,
      last_login_at: 62.days.ago
    )

    original_cancelled_at = practice.cancelled_at

    @task.invoke

    practice.reload
    assert_equal original_cancelled_at.to_i, practice.cancelled_at.to_i
  end

  test 'marks multiple practices with inactive users' do
    # Setup first inactive practice
    practice1 = practices(:trialing_practice)
    practice1.update_columns(cancelled_at: nil)

    User.where(practice_id: practice1.id).destroy_all
    User.create!(
      practice_id: practice1.id,
      firstname: 'Inactive1',
      lastname: 'User',
      email: 'inactive1@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 61.days.ago,
      last_login_at: 62.days.ago
    )

    # Setup second inactive practice
    practice2 = practices(:past_due_practice)
    practice2.update_columns(cancelled_at: nil)

    User.where(practice_id: practice2.id).destroy_all
    User.create!(
      practice_id: practice2.id,
      firstname: 'Inactive2',
      lastname: 'User',
      email: 'inactive2@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      roles: 'admin',
      current_login_at: 70.days.ago,
      last_login_at: 71.days.ago
    )

    @task.invoke

    practice1.reload
    practice2.reload
    assert_not_nil practice1.cancelled_at
    assert_not_nil practice2.cancelled_at
  end
end
