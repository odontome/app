# frozen_string_literal: true

require 'test_helper'

class DeletePracticesCancelledTaskTest < RakeTaskTestCase
  rake_task 'odontome:delete_practices_cancelled_a_while_ago'

  def setup
    super
    travel_to Time.utc(2025, 1, 1, 12, 0, 0)
  end

  def teardown
    travel_back
    super
  end

  test 'destroys practices cancelled more than fifteen days ago' do
    practice = practices(:canceled_practice)
    practice.update_column(:cancelled_at, 16.days.ago)

    @task.invoke

    refute Practice.exists?(practice.id)
  end

  test 'keeps practices cancelled within the last fifteen days' do
    practice = practices(:past_due_practice)
    practice.update_column(:cancelled_at, 10.days.ago)

    @task.invoke

    assert Practice.exists?(practice.id)
  end

  test 'keeps practices that have not been cancelled' do
    practice = practices(:complete)
    practice.update_column(:cancelled_at, nil)

    @task.invoke

    assert Practice.exists?(practice.id)
  end
end
