# frozen_string_literal: true
require 'test_helper'

class OdontogramPartialDentureTest < ActionController::TestCase
  tests OdontogramsController
  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
    @missing = [16,15,12,24].map { |tooth| @patient.odontogram_entries.create!(category: 'missing', tooth: tooth, surfaces: [], recorded_by_name: 'Sample') }
  end

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 13, arch: 'upper', category: 'partial_denture', surfaces: [],
        replacement_teeth: [24,15,16] }.merge(entry) }.merge(operation), as: :json
  end

  test 'disconnected replacements remain one object without including gaps in history' do
    change
    assert_response :created
    entry = @patient.odontogram_entries.find_by!(category: 'partial_denture')
    addition = @patient.odontogram_changes.sole
    assert_equal [16,15,24], entry.member_teeth
    assert_equal entry.member_teeth, entry.replacement_teeth
    [16,15,24].each do |tooth|
      get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 1
    end
    get :show, params: { patient_id: @patient.id, tooth: 13 }, as: :html
    assert_select "[data-history-change='#{addition.id}']", count: 0
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert @missing.all? { |e| e.reload.state == 'active' }
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal [15,16,24], response.parsed_body['comparison']['teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'active', entry.reload.state
  end

  test 'each replacement needs recorded absence and absent teeth cannot be restored under a denture' do
    change({ replacement_teeth: [16,13] })
    assert_response :unprocessable_entity
    change
    assert_response :created
    assert_not @missing.first.update(state: 'removed')
    assert_equal 'active', @missing.first.reload.state
    change({ category: 'filling', tooth: 13, arch: nil, replacement_teeth: [], surfaces: ['F'] })
    assert_response :created
  end

  test 'overlapping replacement sets and full dentures are exclusive but disjoint partials remain separate' do
    change
    assert_response :created
    change({ tooth: 24, replacement_teeth: [12,24] })
    assert_response :unprocessable_entity
    change({ replacement_teeth: [12] })
    assert_response :created
    @patient.odontogram_entries.create!(category: 'edentulous_arch', arch: 'upper', tooth: 13, surfaces: [], recorded_by_name: 'Sample')
    change({ category: 'complete_denture', replacement_teeth: [13,12,11,21,22,23] })
    assert_response :unprocessable_entity
  end

  test 'malformed replacements and restored duplicates cannot bypass the rules' do
    [[], [16,16], [16,46], [16,55]].each do |positions|
      change({ replacement_teeth: positions })
      assert_response :unprocessable_entity
    end
    change({ member_teeth: [13] })
    assert_response :unprocessable_entity
    change
    assert_response :created
    entry = @patient.odontogram_entries.find_by!(category: 'partial_denture')
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    change
    assert_response :created
    assert_not entry.update(state: 'active')
  end

  test 'arch absence supports partials but cannot be corrected unless individual absence still supports every replacement' do
    absence = @patient.odontogram_entries.create!(category: 'edentulous_arch', arch: 'lower', tooth: 43, surfaces: [], recorded_by_name: 'Sample')
    change({ tooth: 85, arch: 'lower', replacement_teeth: [85,84,72] })
    assert_response :created
    assert_not absence.update(state: 'removed')
    [85,84,72].each { |tooth| @patient.odontogram_entries.create!(category: 'missing', tooth: tooth, surfaces: [], recorded_by_name: 'Sample') }
    assert absence.update(state: 'removed')
    entry = @patient.odontogram_entries.find_by!(category: 'partial_denture')
    assert_equal [85,84,72], entry.replacement_teeth
    assert_equal 'active', entry.state
  end

  test 'a complete denture blocks partials even when their replacement positions differ' do
    @patient.odontogram_entries.create!(category: 'edentulous_arch', arch: 'upper', tooth: 13, surfaces: [], recorded_by_name: 'Sample')
    change({ category: 'complete_denture', replacement_teeth: [13,12,11,21,22,23] })
    assert_response :created
    change
    assert_response :unprocessable_entity
  end
end
