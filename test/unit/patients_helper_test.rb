# frozen_string_literal: true

require 'test_helper'

class PatientsHelperTest < ActionView::TestCase
  include PatientsHelper

  test 'patients_sort_link renders plain label when letter is blank' do
    @sort_column = 'name'
    @sort_direction = 'asc'

    result = patients_sort_link(column: 'name', label_key: :name, letter: nil)

    assert_equal I18n.t(:name), result
  end

  test 'patients_sort_link renders inactive column link with ascending next direction' do
    @sort_column = 'name'
    @sort_direction = 'asc'

    result = patients_sort_link(column: 'last_visit', label_key: :last_visit, letter: 'A')

    assert_includes result, 'text-muted'
    assert_includes result, 'sort=last_visit'
    assert_includes result, 'direction=asc'
  end

  test 'patients_sort_link highlights active column and toggles to desc for active asc column' do
    @sort_column = 'name'
    @sort_direction = 'asc'

    result = patients_sort_link(column: 'name', label_key: :name, letter: 'A')

    assert_includes result, 'fw-semibold'
    assert_includes result, 'text-primary'
    assert_includes result, 'direction=desc'
  end

  test 'patients_sort_link toggles to asc for active desc column' do
    @sort_column = 'last_visit'
    @sort_direction = 'desc'

    result = patients_sort_link(column: 'last_visit', label_key: :last_visit, letter: 'A')

    assert_includes result, 'fw-semibold'
    assert_includes result, 'text-primary'
    assert_includes result, 'direction=asc'
  end

  test 'appointment_time_with_duration formats start time and duration' do
    starts_at = Time.zone.parse('2026-03-21 10:30:00')
    ends_at = Time.zone.parse('2026-03-21 11:00:00')

    result = appointment_time_with_duration(starts_at, ends_at)
    assert_includes result, '30 min'
  end
end
