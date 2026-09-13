# frozen_string_literal: true

require 'test_helper'

class PatientsPerformanceTest < ActionController::TestCase
  tests PatientsController

  setup do
    @controller.session['user'] = users(:founder)
    @practice = practices(:complete)
  end

  test 'initial segment pages do not calculate practice-wide badge counts' do
    %w[today needs_follow_up birthdays all].each do |segment|
      queries = capture_queries { get :index, params: { segment: segment } }
      assert_response :success
      counts = queries.grep(/COUNT\(/i).grep(/FROM "(?:patients|appointments)"/)
      assert_empty counts, "#{segment} should defer counts: #{counts.join("\n")}"
      assert_select 'nav[data-patient-counts-url]', count: 1
      assert_select '[data-patient-count="needs_follow_up"][aria-busy="true"]', text: '…'
      assert_select '[data-patient-count="birthdays"][aria-busy="true"]', text: '…'
      assert_empty queries.grep(/LATERAL/i) if segment == 'today'
    end
  end

  test 'patient photo queries stay bounded across every patient listing and pagination format' do
    ids = add_patients(105)
    blob = ActiveStorage::Blob.create!(filename: 'patient.png', content_type: 'image/png', byte_size: 1,
      checksum: Base64.strict_encode64('synthetic'), service_name: 'test')
    # Some patients have photos and others do not; neither case should query per row.
    ids.first(12).each do |id|
      ActiveStorage::Attachment.create!(name: 'profile_picture', record_type: 'Patient', record_id: id, blob: blob)
    end
    Appointment.insert_all!(ids.first(12).map do |id|
      { patient_id: id, doctor_id: doctors(:rebecca).id, datebook_id: datebooks(:playa_del_carmen).id,
        starts_at: Time.current, ends_at: 30.minutes.from_now, status: 'cancelled' }
    end)

    [
      [{ segment: 'today' }, :html],
      [{ segment: 'needs_follow_up' }, :html],
      [{ segment: 'birthdays' }, :html],
      [{ segment: 'all', letter: 'P' }, :html],
      [{ segment: 'all', letter: 'P' }, :js],
      [{ segment: 'new_this_week' }, :html],
      [{ term: 'Perfpatient' }, :html]
    ].each do |params, format|
      queries = capture_queries { get :index, params: params, format: format, xhr: format == :js }
      assert_response :success
      photo_queries = queries.grep(/FROM "active_storage_(attachments|blobs|variant_records)"/)
      puts "#{params} (#{format}): #{photo_queries.size} photo queries" if ENV['PATIENTS_PROFILE'] == '1'
      assert_operator photo_queries.size, :<=, 2, "#{params} (#{format}): #{photo_queries.size} photo queries"
      assert_equal 0, queries.grep(/JOIN "active_storage_/).size, 'photo loading must not expand the listing or pagination SQL'
      records = params[:segment] == 'today' ? assigns(:appointments).map(&:patient) : assigns(:patients)
      assert_operator records.size, :>=, 12
      records.each do |patient|
        assert patient.association(:profile_picture_attachment).loaded?, "photo not preloaded for #{params}"
      end
    end
  end

  test 'follow-up pagination retains never-visited first and returns every patient exactly once' do
    @practice.patients.destroy_all
    ids = add_patients(105)
    visit = 8.months.ago.change(usec: 0)
    Appointment.insert_all!(ids.last(3).map do |id|
      { patient_id: id, doctor_id: doctors(:rebecca).id, datebook_id: datebooks(:playa_del_carmen).id,
        starts_at: visit - 30.minutes, ends_at: visit, status: 'confirmed' }
    end)

    get :index, params: { segment: 'needs_follow_up' }
    assert_equal ids.first(100), assigns(:patients).map(&:id)
    assert_equal 100, assigns(:next_follow_up_offset)
    get :index, params: { segment: 'needs_follow_up', offset: 100 }
    assert_equal ids.last(5), assigns(:patients).map(&:id)
    assert_nil assigns(:next_follow_up_offset)
    assert_equal [nil, nil, visit, visit, visit], assigns(:patients).map(&:last_visit_at)
  end

  test 'segment counts are fresh, private, scoped to the signed-in practice and use lean SQL' do
    @practice.patients.destroy_all
    ids = add_patients(3)
    Patient.where(id: ids.last).update_all(date_of_birth: nil)
    foreign = patients(:three)
    foreign.update_columns(date_of_birth: Time.current.in_time_zone(@practice.timezone).to_date)
    appointment = Appointment.create!(patient_id: ids.first, doctor: doctors(:rebecca),
      datebook: datebooks(:playa_del_carmen), starts_at: Time.current, ends_at: 30.minutes.from_now, status: 'cancelled')

    queries = capture_queries do
      get :segment_counts, params: { practice_id: foreign.practice_id }, format: :json
    end
    assert_response :success
    assert_equal({ 'today' => 1, 'needs_follow_up' => 3, 'birthdays' => 2 }, response.parsed_body)
    assert_includes response.headers['Cache-Control'], 'no-store'
    assert_empty queries.grep(/active_storage_|JOIN "doctors"|JOIN "datebooks"|COUNT\(DISTINCT/i)

    appointment.update!(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes, status: 'unconfirmed')
    get :segment_counts, format: :json
    assert_equal({ 'today' => 0, 'needs_follow_up' => 2, 'birthdays' => 2 }, response.parsed_body)
  end

  test 'segment counts require authentication' do
    @controller.session.delete('user')
    get :segment_counts, format: :json
    assert_redirected_to signin_path
  end

  test 'segment counts follow the impersonated practice' do
    @controller.session['user'] = users(:user_in_yet_another_practice)
    @controller.session[:impersonator_id] = users(:superadmin).id
    foreign_practice = practices(:complete)
    target_practice = users(:user_in_yet_another_practice).practice
    target_practice.patients.destroy_all
    get :segment_counts, params: { practice_id: foreign_practice.id }, format: :json
    assert_response :success
    assert_equal({ 'today' => 0, 'needs_follow_up' => 0, 'birthdays' => 0 }, response.parsed_body)
  end

  private

  def capture_queries
    queries = []
    subscriber = ->(_name, _start, _finish, _id, payload) do
      queries << payload[:sql] if payload[:name] != 'SCHEMA' && payload[:sql].match?(/\ASELECT/i)
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') { yield }
    end
    queries
  end

  def add_patients(count)
    Patient.insert_all!(count.times.map do |index|
      { practice_id: @practice.id, firstname: 'Perfpatient', lastname: format('%04d', index),
        firstname_initial: 'p', fullname_search: "perfpatient #{index}",
        date_of_birth: Time.current.in_time_zone(@practice.timezone).to_date }
    end, returning: %w[id]).rows.flatten.sort
  end
end
