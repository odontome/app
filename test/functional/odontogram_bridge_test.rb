# frozen_string_literal: true
require 'test_helper'

class OdontogramBridgeTest < ActionController::TestCase
  tests OdontogramsController
  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
    @missing = @patient.odontogram_entries.create!(category: 'missing', tooth: 15, surfaces: [], recorded_by_name: 'Sample')
    @units = [{ tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }, { tooth: 14, role: 'natural_support' }]
  end

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'fixed_bridge', surfaces: [], bridge_units: @units }.merge(entry) }.merge(operation), as: :json
  end

  test 'bridge units form one canonical span with shared history snapshots and undo' do
    change({ bridge_units: @units.reverse })
    assert_response :created
    bridge = @patient.odontogram_entries.find_by!(category: 'fixed_bridge')
    addition = @patient.odontogram_changes.sole
    assert_equal [16,15,14], bridge.member_teeth
    assert_equal %w[natural_support pontic natural_support], bridge.bridge_units.map { |unit| unit['role'] }
    [16,15,14].each do |tooth|
      get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 1
    end
    change({}, operation: 'remove', entry_id: bridge.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert_equal 'active', @missing.reload.state
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal bridge.bridge_units, response.parsed_body['entries'].find { |e| e['id'] == bridge.id }['bridge_units']
    assert_equal [14,15,16], response.parsed_body['comparison']['teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal 'active', bridge.reload.state
  end

  test 'missing pontics and natural supports are validated in both entry orders' do
    @missing.update!(state: 'removed')
    change
    assert_response :unprocessable_entity
    @missing.update!(state: 'active')
    change
    assert_response :created
    assert_not @missing.update(state: 'removed')
    %w[missing implant retained_root].each do |category|
      entry = @patient.odontogram_entries.build(category: category, tooth: 16, surfaces: [], recorded_by_name: 'Sample')
      assert_not entry.save, category
    end
    absence = @patient.odontogram_entries.build(category: 'edentulous_arch', tooth: 13, arch: 'upper', surfaces: [], recorded_by_name: 'Sample')
    assert_not absence.save
    @patient.odontogram_entries.create!(category: 'rct', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
  end

  test 'implant supports retain exact identities and cannot be removed while supporting a bridge' do
    implant = @patient.odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    @units.first.merge!(role: 'implant_support', implant_entry_id: implant.id)
    change
    assert_response :created
    bridge = @patient.odontogram_entries.find_by!(category: 'fixed_bridge')
    assert_equal implant.id, bridge.bridge_units.first['implant_entry_id']
    assert_not implant.update(state: 'removed')
    change({}, operation: 'remove', entry_id: bridge.id)
    assert_response :created
    assert implant.update(state: 'removed')
    assert_not bridge.update(state: 'active')
  end

  test 'malformed spans role combinations and foreign implant supports are rejected' do
    invalid = [[], [@units.first], [@units.first, @units.last], [@units[1]],
      [@units.first, @units[1], @units[1]], @units.map { |unit| unit.merge(role: 'pontic') },
      @units.map { |unit| unit.merge(role: 'natural_support') },
      [@units.first, @units[1], { tooth: 44, role: 'natural_support' }]]
    invalid.each do |units|
      change({ bridge_units: units })
      assert_response :unprocessable_entity
    end
    other = patients(:three).odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Other')
    change({ bridge_units: [@units.first.merge(role: 'implant_support', implant_entry_id: other.id), *@units.drop(1)] })
    assert_response :unprocessable_entity
    change({ category: 'crown' })
    assert_response :unprocessable_entity
  end

  test 'a cantilever records one support while duplicate spans and overlapping dentures are blocked' do
    @units = @units.first(2)
    change
    assert_response :created
    change
    assert_response :unprocessable_entity
    change({ category: 'partial_denture', arch: 'upper', replacement_teeth: [15], bridge_units: [] })
    assert_response :unprocessable_entity
  end

  test 'prostheses already covering bridge units prevent adding or restoring the bridge' do
    change
    assert_response :created
    bridge = @patient.odontogram_entries.find_by!(category: 'fixed_bridge')
    change({}, operation: 'remove', entry_id: bridge.id)
    assert_response :created
    @patient.odontogram_entries.create!(category: 'partial_denture', tooth: 15, arch: 'upper', replacement_teeth: [15], surfaces: [], recorded_by_name: 'Sample')
    assert_not bridge.update(state: 'active')
    change
    assert_response :unprocessable_entity
  end

  test 'fully implant supported bridges coexist with arch absence and retain individual absence dependencies' do
    [16,14].each do |tooth|
      implant = @patient.odontogram_entries.create!(category: 'implant', tooth: tooth, surfaces: [], recorded_by_name: 'Sample')
      @units.find { |unit| unit[:tooth] == tooth }.merge!(role: 'implant_support', implant_entry_id: implant.id)
    end
    change
    assert_response :created
    absence = @patient.odontogram_entries.create!(category: 'edentulous_arch', tooth: 13, arch: 'upper', surfaces: [], recorded_by_name: 'Sample')
    assert @missing.update(state: 'removed')
    assert_not absence.update(state: 'removed')
    @missing.update!(state: 'active')
    assert absence.update(state: 'removed')
  end
end
