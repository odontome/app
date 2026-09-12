# frozen_string_literal: true

require 'test_helper'

class OdontogramMobilityTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @practice.update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  teardown { I18n.locale = I18n.default_locale }

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'mobility', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'mobility preserves paired grade and scale through history removal and undo' do
    change({ mobility_grade: ' II ', mobility_scale: ' Miller ' })
    assert_response :created
    entry = @patient.odontogram_entries.sole
    addition = @patient.odontogram_changes.sole
    assert_equal 'II', entry.mobility_grade
    assert_equal 'Miller', entry.mobility_scale
    assert_nil entry.implant_entry_id
    assert_equal 'II', response.parsed_body['entries'].sole['mobility_grade']
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      get :show, params: { patient_id: @patient.id, tooth: 16 }, as: :html
      assert_select "[data-history-change='#{addition.id}']", text: /II \(Miller\)/
      get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
      assert_equal 'II', response.parsed_body['entries'].sole['mobility_grade']
      assert_equal 'Miller', response.parsed_body['entries'].sole['mobility_scale']
    end
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'II', entry.reload.mobility_grade
    assert_equal 'active', entry.state
  end

  test 'mobility grading can be omitted but incomplete oversized and unrelated grading is rejected atomically' do
    [{ mobility_grade: 'II' }, { mobility_scale: 'Miller' },
     { mobility_grade: 'x' * 11, mobility_scale: 'Miller' },
     { mobility_grade: 'II', mobility_scale: 'x' * 61 },
     { category: 'crown', mobility_grade: 'II', mobility_scale: 'Miller' },
     { surfaces: ['O'] }].each do |attributes|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(attributes)
        assert_response :unprocessable_entity
      end
    end
    change
    assert_response :created
    assert_nil @patient.odontogram_entries.sole.mobility_grade
    change({ mobility_grade: 'III', mobility_scale: 'Miller' })
    assert_response :unprocessable_entity
    assert_equal 1, @patient.odontogram_entries.count
  end

  test 'implant mobility uses the actual support and blocks its removal until explicitly corrected' do
    change({ category: 'implant' })
    assert_response :created
    implant = @patient.odontogram_entries.sole
    change({ implant_entry_id: 999999 })
    assert_response :created
    mobility = @patient.odontogram_entries.find_by!(category: 'mobility')
    assert_equal implant.id, mobility.implant_entry_id
    change({}, operation: 'remove', entry_id: implant.id)
    assert_response :unprocessable_entity
    assert_equal 'active', implant.reload.state
    change({}, operation: 'remove', entry_id: mobility.id)
    assert_response :created
    change({}, operation: 'remove', entry_id: implant.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    change({}, operation: 'undo', change_id: @patient.odontogram_changes.where(operation: 'remove', odontogram_entry: mobility).sole.id)
    assert_response :created
    assert_equal 'active', mobility.reload.state
    assert_equal implant.id, mobility.implant_entry_id
  end
end
