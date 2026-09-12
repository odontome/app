# frozen_string_literal: true
require 'test_helper'

class OdontogramRemovableApplianceTest < ActionController::TestCase
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
      odontogram_entry: { tooth: 13, member_teeth: [13, 12, 11, 21, 22, 23], category: 'removable_orthodontic', surfaces: [] }.merge(entry) }.merge(operation), as: :json
  end

  test 'one appliance is visible from every attachment in all locales and undo preserves independent care' do
    crown = @patient.odontogram_entries.create!(tooth: 21, category: 'crown', surfaces: [], recorded_by_name: 'Sample')
    change
    assert_response :created
    appliance = @patient.odontogram_entries.find_by!(category: 'removable_orthodontic')
    addition = @patient.odontogram_changes.sole
    assert_equal [13, 12, 11, 21, 22, 23], response.parsed_body['entries'].last['member_teeth']
    %w[en es pt].each do |locale|
      @practice.update!(locale: locale)
      [13, 12, 11, 21, 22, 23].each do |tooth|
        get :show, params: { patient_id: @patient.id, tooth: tooth }, as: :html
        assert_select "[data-history-change='#{addition.id}']", text: /13, 12, 11, 21, 22, 23/
        assert_select "[data-odontogram-entry='#{appliance.id}']", count: 1
      end
      get :show, params: { patient_id: @patient.id, tooth: 14 }, as: :html
      assert_select "[data-history-change='#{addition.id}']", count: 0
      assert_select "[data-odontogram-entry='#{appliance.id}']", count: 0
    end
    change({}, operation: 'remove', entry_id: appliance.id)
    assert_response :created
    removal = @patient.odontogram_changes.recent.first
    assert_equal 'active', crown.reload.state
    get :show, params: { patient_id: @patient.id, at: addition.id }, as: :json
    assert_equal [13, 12, 11, 21, 22, 23], response.parsed_body['entries'].last['member_teeth']
    assert_equal [11, 12, 13, 21, 22, 23], response.parsed_body['comparison']['teeth']
    change({}, operation: 'undo', change_id: removal.id)
    assert_response :created
    assert_equal [13, 12, 11, 21, 22, 23], appliance.reload.member_teeth
    assert_equal 'active', appliance.state
  end

  test 'whole permanent and primary arches work while overlapping spans and gaps are rejected' do
    OdontogramEntry::ARCHES.each do |arch|
      change({ tooth: arch.last, member_teeth: arch.reverse })
      assert_response :created
      assert_equal arch, @patient.odontogram_entries.order(:id).last.member_teeth
      change({ tooth: arch[2], member_teeth: arch[2..4] })
      assert_response :unprocessable_entity
    end
  end

  test 'invalid and disjoint extents are rejected without creating history' do
    [[], [13,11], [13,33], [13,53], [99], [13,13]].each do |members|
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        change({ member_teeth: members })
        assert_response :unprocessable_entity
      end
    end
    change({ member_teeth: [13,12] })
    assert_response :created
    change({ tooth: 22, member_teeth: [22,23] })
    assert_response :created
  end

  test 'covered positions do not require tooth attachments or change tooth status' do
    %w[missing implant retained_root].zip([14,15,16]).each do |category,tooth|
      @patient.odontogram_entries.create!(tooth: tooth, category: category, surfaces: [], recorded_by_name: 'Sample')
    end
    change({ tooth: 14, member_teeth: [16,15,14,13] })
    assert_response :created
    %w[missing implant retained_root].zip([24,25,26]).each do |category,tooth|
      change({ tooth: tooth, member_teeth: [tooth] })
      assert_response :created
      change({ tooth: tooth, category: category, member_teeth: [] })
      assert_response :created
    end
    assert_equal 6, @patient.odontogram_entries.active.where(category: %w[missing implant retained_root]).count
  end

  test 'custom removable appliances share overlap rules and restoration checks' do
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'removable_orthodontic')
    change({ treatment_id: treatment.id, treatment_version: treatment.reload.updated_at.utc.iso8601(6) })
    assert_response :created
    entry = @patient.odontogram_entries.sole
    assert_equal treatment.name, entry.treatment_snapshot['name']
    entry.update!(state: 'removed')
    change({ tooth: 12, member_teeth: [12,11] })
    assert_response :created
    assert_not entry.update(state: 'active')
    assert_equal 'removed', entry.reload.state
  end
end
