# frozen_string_literal: true
require 'test_helper'

class OdontogramApplianceTest < ActionController::TestCase
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
      odontogram_entry: { tooth: 13, member_teeth: [13, 11, 21, 23], category: 'fixed_orthodontic', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'one appliance is visible from every attachment in all locales and undo preserves independent care' do
    crown = @patient.odontogram_entries.create!(tooth: 21, category: 'crown', surfaces: [], recorded_by_name: 'Sample')
    change
    assert_response :created
    appliance = @patient.odontogram_entries.find_by!(category: 'fixed_orthodontic')
    addition = @patient.odontogram_changes.sole
    assert_equal [13, 11, 21, 23], response.parsed_body['entries'].last['member_teeth']
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      [13, 11, 21, 23].each do |tooth|
        get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
        assert_select "[data-history-change='#{addition.id}']", text: /13, 11, 21, 23/
        assert_select "[data-odontogram-entry='#{appliance.id}']", count: 1
      end
      get :show, params: { patient_id: @patient.id, tooth: 12 }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 0
      assert_select "[data-odontogram-entry='#{appliance.id}']", count: 0
    end
    change({}, operation: 'remove', entry_id: appliance.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert_equal 'active', crown.reload.state
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal [13, 11, 21, 23], response.parsed_body['entries'].last['member_teeth']
    assert_equal [11, 13, 21, 23], response.parsed_body['comparison']['teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal [13, 11, 21, 23], appliance.reload.member_teeth
    assert_equal 'active', appliance.state
  end

  test 'reordered and overlapping attachments are rejected while separate appliances remain allowed' do
    change({ tooth: 23, member_teeth: [23, 21, 11, 13] })
    assert_response :created
    assert_equal 13, @patient.odontogram_entries.sole.tooth
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      change
      assert_response :unprocessable_entity
    end
    [[13,12,11], [12,11], [21]].each do |members|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change({ tooth: members.first, member_teeth: members })
        assert_response :unprocessable_entity
      end
    end
    change({ tooth: 15, member_teeth: [15,14] })
    assert_response :created
    assert_equal 2, @patient.odontogram_entries.active.count
  end

  test 'invalid sets and unrelated category data cannot save' do
    [{ member_teeth: [] }, { member_teeth: [13, 13] }, { member_teeth: [11, 21] },
     { member_teeth: [13, 33] }, { member_teeth: [13, 53] }, { member_teeth: [13, 99] },
     { paired_tooth: 14 }, { category: 'crown' }, { surfaces: ['M'] }].each do |attributes|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change(attributes)
        assert_response :unprocessable_entity
      end
    end
  end

  test 'primary and single attachment appliances and custom presets use the same rules' do
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'fixed_orthodontic')
    change({ tooth: 53, member_teeth: [63, 53], treatment_id: treatment.id, treatment_version: treatment.reload.updated_at.utc.iso8601(6) })
    assert_response :created
    assert_equal [53, 63], @patient.odontogram_entries.sole.member_teeth
    assert_equal treatment.name, @patient.odontogram_entries.sole.treatment_snapshot['name']
    change({ tooth: 33, member_teeth: [33] })
    assert_response :created
    assert_equal [33], @patient.odontogram_entries.order(:id).last.member_teeth
  end

  test 'unavailable attachments need explicit correction in both entry orders' do
    %w[missing implant retained_root].each do |category|
      state = @patient.odontogram_entries.create!(tooth: 21, category: category, surfaces: [], recorded_by_name: 'Sample')
      change
      assert_response :unprocessable_entity
      state.update!(state: 'removed')
    end
    change
    assert_response :created
    %w[missing implant retained_root].each do |category|
      change({ tooth: 21, category: category, member_teeth: [] })
      assert_response :unprocessable_entity
    end
  end

  test 'custom names cannot bypass overlaps and restoring a removed appliance rechecks its attachments' do
    change
    assert_response :created
    original = @patient.odontogram_entries.sole
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'fixed_orthodontic')
    change({ tooth: 12, member_teeth: [12,11], treatment_id: treatment.id,
      treatment_version: treatment.reload.updated_at.utc.iso8601(6) })
    assert_response :unprocessable_entity
    change({}, operation: 'remove', entry_id: original.id)
    assert_response :created
    change({ tooth: 12, member_teeth: [12,11] })
    assert_response :created
    assert_not original.update(state: 'active')
    assert_equal 'removed', original.reload.state
    assert_equal 1, @patient.odontogram_entries.active.count
  end

end
