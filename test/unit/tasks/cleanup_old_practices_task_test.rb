# frozen_string_literal: true

require 'test_helper'

class CleanupOldPractices < RakeTaskTestCase
  rake_task 'odontome:cleanup_old_practices'

  test 'removes practices older than 7 days with 0 patients' do
    practice = practices(:trialing_practice)
    practice.update_columns(created_at: 8.days.ago, patients_count: 0)

    @task.invoke
    assert_equal 0, Practice.where(id: practice.id).count
  end

  test 'does not remove practices with patients' do
    practice = practices(:trialing_practice)
    practice.update_columns(created_at: 12.days.ago, patients_count: 1)

    @task.invoke
    assert_equal 1, Practice.where(id: practice.id).count
  end
end
