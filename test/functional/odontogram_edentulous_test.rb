# frozen_string_literal: true
require 'test_helper'

class OdontogramEdentulousTest < ActionController::TestCase
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
      odontogram_entry: { tooth: 13, arch: 'upper', category: 'edentulous_arch', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'one physical arch includes both dentitions in history snapshots and undo' do
    change
    assert_response :created
    entry = @patient.odontogram_entries.sole
    addition = @patient.odontogram_changes.sole
    assert_equal 'upper', entry.arch
    assert_equal 26, entry.member_teeth.size
    assert_includes entry.member_teeth, 55
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      [11,18,21,28,51,55,61,65].each do |tooth|
        get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
        assert_select "[data-history-change='#{addition.id}']", count: 1
        assert_select "[data-odontogram-entry='#{entry.id}']", count: 1
      end
      get :show, params: { patient_id: @patient.id, tooth: 31 }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 0
    end
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal 'upper', response.parsed_body['entries'].sole['arch']
    assert_equal 26, response.parsed_body['comparison']['teeth'].size
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'active', entry.reload.state
  end

  test 'natural work blocks arch absence and preview identifies conflicts without changing records' do
    crown = @patient.odontogram_entries.create!(tooth: 21, category: 'crown', surfaces: [], recorded_by_name: 'Sample')
    primary = @patient.odontogram_entries.create!(tooth: 55, category: 'filling', surfaces: ['O'], recorded_by_name: 'Sample')
    get :show, params: { patient_id: @patient.id }, as: :json
    assert_equal [crown.id, primary.id].sort, response.parsed_body['arch_conflicts']['upper'].sort
    assert_empty response.parsed_body['arch_conflicts']['lower']
    assert_no_difference ['OdontogramEntry.count','OdontogramChange.count'] do
      change
      assert_response :unprocessable_entity
    end
    assert_equal 'active', crown.reload.state
    assert_equal 'active', primary.reload.state
    change({ tooth: 33, arch: 'lower' })
    assert_response :created
  end

  test 'absence preserves implants their crowns root remnants and removable coverage in both orders' do
    implant = @patient.odontogram_entries.create!(tooth: 21, category: 'implant', surfaces: [], recorded_by_name: 'Sample')
    crown = @patient.odontogram_entries.create!(tooth: 21, category: 'crown', implant_entry: implant, surfaces: [], recorded_by_name: 'Sample')
    change
    assert_response :created
    change({ tooth: 23, arch: nil, category: 'implant' })
    assert_response :created
    change({ tooth: 23, arch: nil, category: 'crown' })
    assert_response :created
    change({ tooth: 24, arch: nil, category: 'retained_root' })
    assert_response :created
    change({ tooth: 18, arch: nil, category: 'removable_orthodontic', member_teeth: [18,17,16] })
    assert_response :created
    assert_equal 'active', implant.reload.state
    assert_equal 'active', crown.reload.state
  end

  test 'absence blocks new natural work and attachment pairs at every position' do
    change
    assert_response :created
    [{ tooth: 55, category: 'filling', surfaces: ['O'] }, { tooth: 26, category: 'crown' },
     { tooth: 12, category: 'fusion', paired_tooth: 11 }, { tooth: 11, category: 'fixed_orthodontic', member_teeth: [11,21] }].each do |entry|
      change(entry.merge(arch: nil))
      assert_response :unprocessable_entity
    end
    change({ tooth: 53 })
    assert_response :unprocessable_entity
  end

  test 'invalid or partial arches and unrelated arch data are rejected' do
    [{ arch: nil }, { arch: 'left' }, { arch: 'lower' }, { member_teeth: [13] },
     { surfaces: ['F'] }, { paired_tooth: 14 }, { category: 'crown' }].each do |entry|
      change(entry)
      assert_response :unprocessable_entity
    end
  end

  test 'restoring an arch rechecks natural work added since its removal' do
    change
    assert_response :created
    entry = @patient.odontogram_entries.sole
    change({}, operation: 'remove', entry_id: entry.id)
    assert_response :created
    crown = @patient.odontogram_entries.create!(tooth: 55, category: 'crown', surfaces: [], recorded_by_name: 'Sample')
    assert_not entry.update(state: 'active')
    assert_equal 'removed', entry.reload.state
    assert_equal 'active', crown.reload.state
  end

end
