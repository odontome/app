# frozen_string_literal: true

require 'test_helper'

class OdontogramHistoryTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @practice.update!(odontogram_enabled: true, timezone: 'Eastern Time (US & Canada)')
    @entry = @patient.odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], recorded_by_name: 'Original author')
  end

  teardown do
    I18n.locale = I18n.default_locale
  end

  def record(at:, patient: @patient, entry: @entry, **attributes)
    patient.odontogram_changes.create!({ odontogram_entry: entry, operation: 'add', recorded_by_name: 'Sample author',
      request_id: SecureRandom.uuid, editor_id: SecureRandom.uuid, request_digest: 'test',
      revision: (patient.odontogram_changes.maximum(:revision) || 0) + 1, after_state: entry.chart_attributes,
      created_at: at }.merge(attributes))
  end

  test 'history groups recorded days in the practice timezone rather than observation dates' do
    record(at: Time.utc(2026, 9, 11, 3, 59), after_state: @entry.chart_attributes.merge('observed_on' => '2020-01-01'))
    record(at: Time.utc(2026, 9, 11, 4, 1))
    record(at: Time.utc(2026, 9, 11, 4, 2))
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_response :success
    assert_select '[data-odontogram-session-enabled="true"]'
    assert_select '[data-history-day]', count: 2
    assert_select '[data-history-day="2026-09-11"] [data-history-change]', count: 2
    assert_select '[data-history-day="2026-09-10"] [data-history-change]', count: 1
    assert_select '[data-history-day="2020-01-01"]', count: 0
    assert_includes response.body, '2020'
  end

  test 'ten days and five changes per day are initially shown with bounded older history' do
    11.times { |i| record(at: Time.utc(2026, 9, 10, 12) - i.days) }
    6.times { |i| record(at: Time.utc(2026, 9, 10, 13, i)) }
    get :show, params: { patient_id: @patient.id }, as: :html
    assert_select '[data-history-day]', count: 10
    assert_select '[data-history-day="2026-09-10"] [data-history-change]', count: 5
    assert_select "a[href='#{patient_odontogram_path(@patient, before_day: '2026-09-01')}']"
    assert_select "a[href='#{patient_odontogram_path(@patient, history_day: '2026-09-10')}']"
    get :show, params: { patient_id: @patient.id, before_day: '2026-09-01' }, as: :html
    assert_select '[data-history-day]', count: 1
    assert_select '[data-history-day="2026-08-31"]'
  end

  test 'a busy day pages every event without duplicates and scopes its cursor' do
    changes = 51.times.map { |i| record(at: Time.utc(2026, 9, 10, 12, i)) }
    get :show, params: { patient_id: @patient.id, history_day: '2026-09-10' }, as: :html
    assert_select '[data-history-change]', count: 50
    cursor = changes[1]
    get :show, params: { patient_id: @patient.id, history_day: '2026-09-10', before_change: cursor.id }, as: :html
    assert_select '[data-history-change]', count: 1
    assert_select "[data-history-change='#{changes.first.id}']"
    other_entry = patients(:three).odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], recorded_by_name: 'Other')
    other = record(at: Time.utc(2026, 9, 10, 12), patient: patients(:three), entry: other_entry)
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, history_day: '2026-09-10', before_change: other.id }, as: :html
    end
  end

  test 'a daylight saving day includes both repeated hours and excludes the next midnight' do
    first = record(at: Time.utc(2026, 11, 1, 5, 30))
    second = record(at: Time.utc(2026, 11, 1, 6, 30))
    record(at: Time.utc(2026, 11, 2, 5))
    get :show, params: { patient_id: @patient.id, history_day: '2026-11-01' }, as: :html
    assert_select '[data-history-change]', count: 2
    assert_select "[data-history-change='#{first.id}']", text: /01:30 EDT/
    assert_select "[data-history-change='#{second.id}']", text: /01:30 EST/
  end

  test 'today is identified as latest saved activity and spring daylight saving stays within its day' do
    travel_to Time.utc(2026, 3, 8, 20) do
      record(at: Time.utc(2026, 3, 8, 5))
      record(at: Time.utc(2026, 3, 9, 3, 59))
      tomorrow = record(at: Time.utc(2026, 3, 9, 4))
      get :show, params: { patient_id: @patient.id }, as: :html
      assert_select '[data-history-day="2026-03-08"]', text: /Latest changes saved today/
      get :show, params: { patient_id: @patient.id, history_day: '2026-03-08' }, as: :html
      assert_select '[data-history-change]', count: 2
      assert_select "[data-history-change='#{tomorrow.id}']", count: 0
    end
  end

  test 'history uses saved names and shows undo outcomes while read only in all locales' do
    snapshot = @entry.chart_attributes.merge('treatment_snapshot' => { 'name' => '<script>Old crown</script>' })
    record(at: Time.utc(2026, 9, 10, 12), after_state: snapshot)
    removal = record(at: Time.utc(2026, 9, 10, 13), operation: 'remove', before_state: snapshot, after_state: snapshot.merge('state' => 'removed'))
    reversal = record(at: Time.utc(2026, 9, 10, 14), operation: 'undo', reverses_id: removal.id,
      before_state: removal.after_state, after_state: snapshot)
    @entry.update!(treatment_snapshot: { name: 'Different label' })
    %w[en es pt].each do |locale|
      @practice.update!(odontogram_enabled: false, locale: locale)
      get :show, params: { patient_id: @patient.id }, as: :html
      assert_response :success
      assert_select '[data-odontogram-session-enabled="false"]'
      assert_select '[data-history-change]', count: 3
      assert_select "[data-history-change='#{reversal.id}']", text: /#{Regexp.escape(I18n.t('odontogram.history.undo_restored'))}/
      assert_select '[data-history-change] script', count: 0
      assert_includes response.body, '&lt;script&gt;Old crown&lt;/script&gt;'
      assert_select '.translation_missing', count: 0
      assert_select '[data-odontogram-history] form, [data-odontogram-history] input, canvas', count: 0
    end
  end

  test 'malformed history dates are rejected without a server error' do
    ['not-a-date', '2026-02-31', ['2026-09-10']].each do |date|
      get :show, params: { patient_id: @patient.id, history_day: date }, as: :html
      assert_response :bad_request
    end
  end
  test 'tooth history filters events and records and preserves filters through day pagination' do
    other_entry = @patient.odontogram_entries.create!(category: 'crown', tooth: 13, surfaces: [], recorded_by_name: 'Other tooth')
    other = record(at: Time.utc(2026, 9, 10, 12), entry: other_entry)
    changes = 51.times.map { |i| record(at: Time.utc(2026, 9, 10, 13, i)) }
    get :show, params: { patient_id: @patient.id, tooth: '16' }, as: :html
    assert_response :success
    assert_select '[data-odontogram-history] h2', text: /Tooth 16/
    assert_select "[data-history-change='#{other.id}']", count: 0
    assert_select '[data-history-change]', count: 5
    assert_select '[data-history-change]', text: /Tooth 16/, count: 0
    assert_select '[data-odontogram-entry]', count: 1
    assert_select "a[href='#{patient_odontogram_path(@patient, tooth: 16, history_day: '2026-09-10')}']"
    get :show, params: { patient_id: @patient.id, tooth: '16', history_day: '2026-09-10' }, as: :html
    assert_select '[data-history-change]', count: 50
    assert_select "a[href='#{patient_odontogram_path(@patient, tooth: 16, history_day: '2026-09-10', before_change: changes[1].id)}']"
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, tooth: '16', history_day: '2026-09-10', before_change: other.id }, as: :html
    end
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, tooth: '16', before: other_entry.id }, as: :html
    end
  end

  test 'saved tooth history excludes later revisions and current records in every locale' do
    first = record(at: Time.utc(2026, 9, 10, 12))
    cutoff = record(at: Time.utc(2026, 9, 10, 13))
    later = record(at: Time.utc(2026, 9, 10, 14), operation: 'remove', after_state: @entry.chart_attributes.merge('state' => 'removed'))
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, tooth: '16', through: cutoff.id, history_day: '2026-09-10' }, as: :html
      assert_response :success
      assert_select '[data-history-change]', count: 2
      assert_select "[data-history-change='#{first.id}']"
      assert_select "[data-history-change='#{later.id}']", count: 0
      assert_select '[data-odontogram-records]', count: 0
      assert_select '[data-history-cutoff]'
      assert_select '[data-odontogram-session-enabled="true"]'
      assert_select "a[href='#{patient_odontogram_path(@patient, tooth: 16, through: cutoff.id)}']"
      assert_select "a[href='#{patient_odontogram_path(@patient, through: cutoff.id)}']"
      assert_select "a[href='#{patient_odontogram_path(@patient, at: cutoff.id)}']"
      assert_select '.translation_missing', count: 0
    end
    post :create, params: { patient_id: @patient.id, through: cutoff.id }, as: :json
    assert_response :forbidden
  end

  test 'tooth and cutoff filters reject malformed values and another patients cutoff' do
    ['99', '16garbage', ['16']].each do |tooth|
      get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
      assert_response :bad_request
    end
    ['0', '1garbage', ['1']].each do |through|
      get :show, params: { patient_id: @patient.id, through: through }, as: :html
      assert_response :bad_request
    end
    other_entry = patients(:three).odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], recorded_by_name: 'Other')
    other = record(at: Time.utc(2026, 9, 10, 12), patient: patients(:three), entry: other_entry)
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, through: other.id }, as: :html
    end
  end

  test 'older days keep tooth and cutoff filters and cannot page into later events' do
    11.times { |i| record(at: Time.utc(2026, 9, 1, 12) + i.days) }
    cutoff = @patient.odontogram_changes.recent.first
    later = record(at: Time.utc(2026, 9, 12, 12))
    filters = { tooth: 16, through: cutoff.id }
    get :show, params: { patient_id: @patient.id, **filters }, as: :html
    assert_select '[data-history-day]', count: 10
    assert_select "[data-history-change='#{later.id}']", count: 0
    assert_select "a[href='#{patient_odontogram_path(@patient, **filters, before_day: '2026-09-02')}']"
    get :show, params: { patient_id: @patient.id, **filters, before_day: '2026-09-02' }, as: :html
    assert_select '[data-history-day]', count: 1
    assert_select '[data-history-day="2026-09-01"]'
    assert_raises ActiveRecord::RecordNotFound do
      get :show, params: { patient_id: @patient.id, **filters, history_day: '2026-09-12', before_change: later.id }, as: :html
    end
    get :show, params: { patient_id: @patient.id, **filters }, as: :json
    assert_response :bad_request
  end

end
