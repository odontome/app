# frozen_string_literal: true
require 'test_helper'

class OdontogramDentureTest < ActionController::TestCase
  tests OdontogramsController
  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  def absence(arch = 'upper')
    @patient.odontogram_entries.create!(category: 'edentulous_arch', arch: arch,
      tooth: arch == 'upper' ? 13 : 43, surfaces: [], recorded_by_name: 'Sample')
  end

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 13, arch: 'upper', category: 'complete_denture', surfaces: [],
        replacement_teeth: [17,16,15,14,13,12,11,21,22,23,24,25,26,27] }.merge(entry) }.merge(operation), as: :json
  end

  test 'one denture preserves separate arch absence through correction undo and snapshots' do
    missing = absence
    change
    assert_response :created
    denture = @patient.odontogram_entries.find_by!(category: 'complete_denture')
    addition = @patient.odontogram_changes.sole
    assert_equal 14, denture.replacement_teeth.size
    assert_equal 26, denture.member_teeth.size
    assert_equal 2, @patient.odontogram_entries.active.count
    assert_not missing.update(state: 'removed')
    change({}, operation: 'remove', entry_id: denture.id)
    assert_response :created
    assert_equal 'active', missing.reload.state
    removal = @patient.odontogram_changes.recent.first
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal denture.replacement_teeth, response.parsed_body['entries'].find { |e| e['id'] == denture.id }['replacement_teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'active', denture.reload.state
    [13,18,55].each do |tooth|
      get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 1
    end
  end

  test 'absence must be recorded first and one denture per physical arch also applies on restoration' do
    change
    assert_response :unprocessable_entity
    absence
    change
    assert_response :created
    original = @patient.odontogram_entries.find_by!(category: 'complete_denture')
    change({ tooth: 55, replacement_teeth: [55,54,53,52,51,61,62,63,64,65] })
    assert_response :unprocessable_entity
    change({}, operation: 'remove', entry_id: original.id)
    assert_response :created
    change
    assert_response :created
    assert_not original.update(state: 'active')
    absence('lower')
    change({ tooth: 43, arch: 'lower', replacement_teeth: [43,42,41,31,32,33] })
    assert_response :created
  end

  test 'replacement positions are explicit unique and in one dentition of the selected arch' do
    absence
    [[], [13,13], [13,43], [13,53], [99]].each do |positions|
      change({ replacement_teeth: positions })
      assert_response :unprocessable_entity
    end
    change({ member_teeth: [13] })
    assert_response :unprocessable_entity
    change({ surfaces: ['F'] })
    assert_response :unprocessable_entity
    change({ category: 'edentulous_arch' })
    assert_response :unprocessable_entity
  end

  test 'denture leaves recorded implants and roots intact without assigning an invented support' do
    implant = @patient.odontogram_entries.create!(category: 'implant', tooth: 13, surfaces: [], recorded_by_name: 'Sample')
    root = @patient.odontogram_entries.create!(category: 'retained_root', tooth: 15, surfaces: [], recorded_by_name: 'Sample')
    absence
    change
    assert_response :created
    denture = @patient.odontogram_entries.find_by!(category: 'complete_denture')
    assert_nil denture.implant_entry_id
    assert_equal 'active', implant.reload.state
    assert_equal 'active', root.reload.state
    change({}, operation: 'remove', entry_id: denture.id)
    assert_response :created
    assert_equal 'active', implant.reload.state
  end
end
