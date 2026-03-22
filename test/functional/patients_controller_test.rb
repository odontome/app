# frozen_string_literal: true

require 'test_helper'

class PatientsControllerTest < ActionController::TestCase
  setup do
    @controller.session['user'] = users(:founder)

    @new_patient = {
      firstname: 'Daniella',
      lastname: 'Sanguino',
      date_of_birth: '1988-11-16',
      uid: 'RR0001'
    }
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_equal 'today', assigns(:segment)
  end

  test 'index defaults to today segment' do
    get :index
    assert_response :success
    assert_equal 'today', assigns(:segment)
  end

  test 'today segment shows all todays appointments including cancelled' do
    practice = practices(:complete)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    patient = Patient.create!(
      practice: practice, firstname: 'Visit', lastname: 'Today',
      uid: 'VT001', date_of_birth: Date.new(1990, 1, 1)
    )

    today_appt = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: Time.current.change(hour: 10), ends_at: Time.current.change(hour: 10, min: 30),
      status: Appointment.status[:confirmed]
    )

    yesterday_appt = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: 1.day.ago.change(hour: 10), ends_at: 1.day.ago.change(hour: 10, min: 30),
      status: Appointment.status[:confirmed]
    )

    cancelled_appt = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: Time.current.change(hour: 14), ends_at: Time.current.change(hour: 14, min: 30),
      status: Appointment.status[:cancelled]
    )

    get :index
    appointment_ids = assigns(:appointments).map(&:id)

    assert_includes appointment_ids, today_appt.id
    assert_includes appointment_ids, cancelled_appt.id
    refute_includes appointment_ids, yesterday_appt.id
  end

  test 'today segment empty state' do
    Appointment.where(
      status: [Appointment.status[:confirmed], Appointment.status[:waiting_room]]
    ).where(starts_at: Time.current.beginning_of_day..Time.current.end_of_day).destroy_all

    get :index
    assert_response :success
    assert_equal 'today', assigns(:segment)
    assert assigns(:appointments).empty?
  end

  test 'all segment preserves existing letter behavior' do
    get :index, params: { segment: 'all' }
    assert_response :success
    assert_equal 'all', assigns(:segment)
    assert_not_nil assigns(:patients)
    assert_not_nil assigns(:current_letter)
  end

  test 'letter param infers all segment' do
    get :index, params: { letter: 'A' }
    assert_response :success
    assert_equal 'all', assigns(:segment)
  end

  test 'segment pills not shown during search' do
    get :index, params: { term: 'test' }
    assert_response :success
    assert_nil assigns(:segment)
  end

  test 'needs_follow_up segment shows patients with no recent visit and no future appointment' do
    practice = practices(:complete)
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    # Patient with old visit and no future appointment — should appear
    overdue_patient = Patient.create!(
      practice: practice, firstname: 'Overdue', lastname: 'Patient',
      uid: 'OVD001', date_of_birth: Date.new(1985, 5, 5)
    )
    Appointment.create!(
      datebook: datebook, doctor: doctor, patient: overdue_patient,
      starts_at: 8.months.ago, ends_at: 8.months.ago + 30.minutes,
      status: Appointment.status[:confirmed]
    )

    # Patient with recent visit — should NOT appear
    recent_patient = Patient.create!(
      practice: practice, firstname: 'Recent', lastname: 'Patient',
      uid: 'RCT001', date_of_birth: Date.new(1990, 1, 1)
    )
    Appointment.create!(
      datebook: datebook, doctor: doctor, patient: recent_patient,
      starts_at: 2.months.ago, ends_at: 2.months.ago + 30.minutes,
      status: Appointment.status[:confirmed]
    )

    # Patient with old visit but a future appointment — should NOT appear
    scheduled_patient = Patient.create!(
      practice: practice, firstname: 'Scheduled', lastname: 'Patient',
      uid: 'SCH001', date_of_birth: Date.new(1992, 3, 3)
    )
    Appointment.create!(
      datebook: datebook, doctor: doctor, patient: scheduled_patient,
      starts_at: 7.months.ago, ends_at: 7.months.ago + 30.minutes,
      status: Appointment.status[:confirmed]
    )
    Appointment.create!(
      datebook: datebook, doctor: doctor, patient: scheduled_patient,
      starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 30.minutes,
      status: Appointment.status[:confirmed]
    )

    get :index, params: { segment: 'needs_follow_up' }

    assert_response :success
    assert_equal 'needs_follow_up', assigns(:segment)

    patient_ids = assigns(:patients).map(&:id)
    assert_includes patient_ids, overdue_patient.id
    refute_includes patient_ids, recent_patient.id
    refute_includes patient_ids, scheduled_patient.id
  end

  test 'needs_follow_up segment empty state' do
    # Delete all patients so none can be overdue
    Patient.with_practice(practices(:complete).id).destroy_all

    get :index, params: { segment: 'needs_follow_up' }

    assert_response :success
    assert_equal 'needs_follow_up', assigns(:segment)
    assert_empty assigns(:patients)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create patient' do
    assert_difference('Patient.count') do
      post :create, params: { patient: @new_patient }
    end
    assert_redirected_to patient_path(assigns(:patient))
  end

  test 'should show patient' do
    get :show, params: { id: patients(:one).to_param }
    assert_response :success
  end

  test 'should get edit' do
    get :edit, params: { id: patients(:one).to_param }
    assert_response :success
  end

  test 'should get search results' do
    get :index, params: { term: patients(:four).firstname }
    assert_not_nil assigns(:patients)
  end

  test 'should not get search results' do
    get :index, params: { term: patients(:four).email }
    assert assigns(:patients).empty?
  end

  test 'should handle search with backslash character' do
    # This test ensures the SQL injection vulnerability is fixed
    # Previously, searching with a term ending in backslash would cause a PostgreSQL error
    get :index, params: { term: 'test\\' }
    assert_response :success
    assert_not_nil assigns(:patients)
    # Should return empty results but not cause an error
    assert assigns(:patients).empty?
  end

  test 'should handle search with other special characters' do
    # Test searching with other LIKE pattern special characters
    get :index, params: { term: 'test%_' }
    assert_response :success
    assert_not_nil assigns(:patients)
    # Should return empty results but not cause an error
    assert assigns(:patients).empty?
  end

  test 'should update patient' do
    put :update, params: { id: patients(:one).to_param, patient: @new_patient }
    assert_redirected_to patient_path(assigns(:patient))
  end

  test 'should destroy patient' do
    assert_difference('Patient.count', -1) do
      delete :destroy, params: { id: patients(:one).to_param }
    end

    assert_redirected_to patients_path
  end

  test 'non-admin cannot destroy patient' do
    @controller.session['user'] = users(:perishable) # roles: user, not admin

    assert_no_difference('Patient.count') do
      delete :destroy, params: { id: patients(:one).to_param }
    end
  end

  test 'letter listing uses cursor pagination' do
    practice = practices(:complete)
    total_records = PatientsController::LETTER_PAGE_SIZE + 1

    total_records.times do |index|
      Patient.create!(
        practice: practice,
        firstname: "Alice#{index}",
        lastname: 'Cursor',
        uid: "CUR#{index}",
        date_of_birth: Date.new(1990, 1, 1)
      )
    end

    get :index, params: { letter: 'A' }

    assert_response :success
    assert_equal PatientsController::LETTER_PAGE_SIZE, assigns(:patients).size
    assert assigns(:next_cursor).present?
    assert_equal 'A', assigns(:current_letter)
  end

  test 'cursor parameter returns subsequent patients' do
    practice = practices(:complete)
    total_records = PatientsController::LETTER_PAGE_SIZE + 1

    total_records.times do |index|
      Patient.create!(
        practice: practice,
        firstname: format('Aaron%03d', index),
        lastname: 'FollowUp',
        uid: "CURA#{index}",
        date_of_birth: Date.new(1990, 2, 2)
      )
    end

    get :index, params: { letter: 'A' }
    cursor = assigns(:next_cursor)

    assert cursor.present?

    get :index, params: { letter: 'A', cursor: cursor }

    assert_response :success
    assert assigns(:patients).size.positive?
    assert_nil assigns(:next_cursor)
  end

  test 'overflow patient becomes first record on next cursor page' do
    practice = practices(:complete)
    practice.patients.destroy_all
    total_records = PatientsController::LETTER_PAGE_SIZE + 5

    total_records.times do |index|
      Patient.create!(
        practice: practice,
        firstname: format('Alex%03d', index),
        lastname: 'Pager',
        uid: "CURK#{index}",
        date_of_birth: Date.new(1991, 3, 3)
      )
    end

    expected_second_page_first = Patient
                                 .where(practice: practice)
                                 .order('firstname ASC, lastname ASC, id ASC')
                                 .offset(PatientsController::LETTER_PAGE_SIZE)
                                 .first

    get :index, params: { letter: 'A' }
    cursor = assigns(:next_cursor)

    assert_equal PatientsController::LETTER_PAGE_SIZE, assigns(:patients).size
    assert cursor.present?

    get :index, params: { letter: 'A', cursor: cursor }

    assert_equal expected_second_page_first.id, assigns(:patients).first.id

    remaining_records = total_records - PatientsController::LETTER_PAGE_SIZE
    expected_second_page_size = [remaining_records, PatientsController::LETTER_PAGE_SIZE].min
    assert_equal expected_second_page_size, assigns(:patients).size
  end

  test 'last visit sort uses cursor pagination' do
    practice = practices(:complete)
    total_records = PatientsController::LETTER_PAGE_SIZE + 1
    created_patients = []

    total_records.times do |index|
      patient = Patient.create!(
        practice: practice,
        firstname: format('AVisit%03d', index),
        lastname: 'Return',
        uid: "VIS#{index}",
        date_of_birth: Date.new(1992, 4, 4)
      )

      visit_time = (index + 1).days.ago.change(usec: 0)

      Appointment.create!(
        datebook: datebooks(:playa_del_carmen),
        doctor: doctors(:rebecca),
        patient: patient,
        starts_at: visit_time - 1.hour,
        ends_at: visit_time,
        status: Appointment.status[:confirmed]
      )

      created_patients << { patient: patient, visit_time: visit_time }
    end

    expected_order = created_patients.sort_by { |row| [-row[:visit_time].to_i, row[:patient].id] }

    get :index, params: { letter: 'A', sort: 'last_visit', direction: 'desc' }

    assert_response :success
    assert_equal 'last_visit', assigns(:sort_column)
    assert_equal 'desc', assigns(:sort_direction)
    assert_equal PatientsController::LETTER_PAGE_SIZE, assigns(:patients).size
    assert_equal expected_order.first[:patient].id, assigns(:patients).first.id

    cursor = assigns(:next_cursor)
    assert cursor.present?

    get :index, params: { letter: 'A', sort: 'last_visit', direction: 'desc', cursor: cursor }

    assert_response :success
    assert_equal expected_order[PatientsController::LETTER_PAGE_SIZE][:patient].id, assigns(:patients).first.id
    assert_nil assigns(:next_cursor)
  end

  test 'today segment respects practice timezone' do
    practice = practices(:complete) # Europe/London
    doctor = doctors(:rebecca)
    datebook = datebooks(:playa_del_carmen)

    patient = Patient.create!(
      practice: practice, firstname: 'Timezone', lastname: 'Test',
      uid: 'TZ001', date_of_birth: Date.new(1990, 1, 1)
    )

    # Freeze time to 11 PM London time (March 21)
    london_tz = ActiveSupport::TimeZone['Europe/London']
    frozen_time = london_tz.parse('2026-03-21 23:00:00')

    travel_to frozen_time do
      late_appt = Appointment.create!(
        datebook: datebook, doctor: doctor, patient: patient,
        starts_at: london_tz.parse('2026-03-21 22:00:00'),
        ends_at: london_tz.parse('2026-03-21 22:30:00'),
        status: Appointment.status[:confirmed]
      )

      get :index
      assert_response :success
      appointment_ids = assigns(:appointments).map(&:id)
      assert_includes appointment_ids, late_appt.id
    end
  end

  test 'changing sort column ignores stale cursor and returns first page' do
    practice = practices(:complete)

    3.times do |index|
      Patient.create!(
        practice: practice,
        firstname: format('AStale%03d', index),
        lastname: 'Cursor',
        uid: "STL#{index}",
        date_of_birth: Date.new(1990, 1, 1)
      )
    end

    get :index, params: { letter: 'A', sort: 'last_visit', direction: 'desc' }
    cursor = assigns(:next_cursor)

    get :index, params: { letter: 'A', sort: 'name', direction: 'asc', cursor: cursor }

    assert_response :success
    assert_equal 'name', assigns(:sort_column)
    assert_equal 'asc', assigns(:sort_direction)
    assert assigns(:patients).size > 0, 'should return patients despite stale cursor'
  end
end
