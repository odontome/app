# frozen_string_literal: true

require 'test_helper'

class OdontogramTreatmentsTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    @practice = practices(:complete)
    @practice.update!(odontogram_enabled: true)
    @treatment = treatments(:complete)
    @treatment.update!(name: 'Composite restoration', odontogram_category: 'filling')
    @treatment.reload
    @editor = SecureRandom.uuid
  end

  def add_preset(request_id: SecureRandom.uuid, **overrides)
    post :create, params: { patient_id: @patient.id, operation: 'add', revision: @patient.reload.odontogram_revision,
      editor_id: @editor, request_id: request_id,
      odontogram_entry: { tooth: 16, category: 'filling', surfaces: %w[M O], treatment_id: @treatment.id,
        treatment_version: @treatment.updated_at.utc.iso8601(6) }.merge(overrides) }, as: :json
  end

  test 'all custom treatment families share target rules duplicate protection and correction history' do
    surface_categories = %w[caries filling temporary_filling inlay wear]
    OdontogramEntry::CATEGORIES.each_with_index do |category, index|
      @treatment.update!(odontogram_category: category)
      endpoints = { 'diastema' => [51, 61], 'fusion' => [53, 52], 'transposition' => [54, 64] }[category]
      endpoints = [55, 65] if category == 'fixed_orthodontic'
      endpoints = [81, 71] if category == 'removable_orthodontic'
      tooth = endpoints ? endpoints.first : OdontogramEntry::TEETH[index]
      pair = endpoints ? { paired_tooth: endpoints.last } : {}
      pair = { member_teeth: endpoints } if OdontogramEntry::GROUP_CATEGORIES.include?(category)
      if OdontogramEntry::ARCH_CATEGORIES.include?(category)
        # Earlier families are already verified; prepare an arch without current natural work.
        @patient.odontogram_entries.active.order(id: :desc).each { |entry| entry.update!(state: 'removed') }
        pair = { arch: 'upper' }
        if OdontogramEntry::DENTURE_CATEGORIES.include?(category)
          @patient.odontogram_entries.create!(category: 'edentulous_arch', tooth: 13, arch: 'upper', surfaces: [], recorded_by_name: 'Sample')
          pair[:replacement_teeth] = [13,12,11,21,22,23]
        end
        tooth = 13
      end
      if category == 'fixed_bridge'
        @patient.odontogram_entries.create!(category: 'missing', tooth: 42, surfaces: [], recorded_by_name: 'Sample')
        tooth = 43
        pair = { bridge_units: [{ tooth: 43, role: 'natural_support' }, { tooth: 42, role: 'pontic' }, { tooth: 41, role: 'natural_support' }] }
      end
      surfaces = surface_categories.include?(category) ? %w[M D] : []
      add_preset(tooth: tooth, category: category, surfaces: surfaces, **pair)
      assert_response :created, category
      entry = @patient.odontogram_entries.order(:id).last
      assert_equal surfaces, entry.surfaces
      assert_equal @treatment.name, entry.treatment_snapshot['name']
      assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
        add_preset(tooth: tooth, category: category, surfaces: surfaces.reverse, **pair)
        assert_response :unprocessable_entity, category
        add_preset(tooth: tooth, category: category, surfaces: surfaces, observed_on: Date.tomorrow, **pair)
        assert_response :unprocessable_entity, category
      end
      post :create, params: { patient_id: @patient.id, operation: 'remove', entry_id: entry.id,
        revision: @patient.reload.odontogram_revision, editor_id: @editor, request_id: SecureRandom.uuid }, as: :json
      assert_response :created, category
      removal = @patient.odontogram_changes.recent.first
      post :create, params: { patient_id: @patient.id, operation: 'undo', change_id: removal.id,
        revision: @patient.reload.odontogram_revision, editor_id: @editor, request_id: SecureRandom.uuid }, as: :json
      assert_response :created, category
      assert_equal 'active', entry.reload.state
      assert_equal surfaces, entry.surfaces
    end
  end

  test 'chart offers only configured treatments belonging to the current practice' do
    other = practices(:trialing_practice).treatments.create!(name: 'Other practice', price: 20, odontogram_category: 'crown')
    get :show, params: { patient_id: @patient.id }, as: :json
    assert_response :success
    assert_equal [{ 'id' => @treatment.id, 'name' => 'Composite restoration', 'category' => 'filling',
      'version' => @treatment.updated_at.utc.iso8601(6) }], response.parsed_body['presets']
    assert_not_includes response.body, other.name
  end

  test 'custom implant crowns keep their support and labels after catalogue changes' do
    implant = @patient.odontogram_entries.create!(tooth: 16, category: 'implant', surfaces: [], recorded_by_name: 'Sample')
    @treatment.update!(name: 'Zirconia crown', odontogram_category: 'crown')
    other_implant = patients(:three).odontogram_entries.create!(tooth: 16, category: 'implant', surfaces: [], recorded_by_name: 'Other')
    add_preset(category: 'crown', surfaces: [], implant_entry_id: other_implant.id)
    assert_response :created
    crown = @patient.odontogram_entries.find_by!(category: 'crown')
    assert_equal implant.id, crown.implant_entry_id
    @treatment.update!(name: 'New name', odontogram_category: 'filling')
    %i[en es pt].each do |locale|
      I18n.with_locale(locale) do
        get :show, params: { patient_id: @patient.id }, as: :html
        assert_response :success
        assert_select "[data-odontogram-entry='#{crown.id}']", text: /Zirconia crown.*#{Regexp.escape(I18n.t('odontogram.editor.on_implant'))}/
      end
    end
    assert_equal implant.id, crown.odontogram_changes.sole.after_state['implant_entry_id']
  end

  test 'saving a preset captures its identity and name without creating a charge' do
    assert_no_difference 'Balance.count' do
      add_preset(treatment_snapshot: { name: 'Forged label' })
    end
    assert_response :created
    entry = @patient.odontogram_entries.sole
    assert_equal({ 'id' => @treatment.id, 'name' => 'Composite restoration' }, entry.treatment_snapshot)
    assert_equal 'filling', entry.category
    assert_equal %w[M O], entry.surfaces
    assert_equal entry.chart_attributes, @patient.odontogram_changes.sole.after_state
  end

  test 'renaming changing and deleting a preset preserves the chart history and undo' do
    add_preset
    entry = @patient.odontogram_entries.sole
    original = entry.chart_attributes
    @treatment.update!(name: 'New name', odontogram_category: 'crown')
    @treatment.destroy!
    assert_equal original, entry.reload.chart_attributes
    assert_equal original, @patient.odontogram_changes.sole.after_state

    get :show, params: { patient_id: @patient.id }, as: :html
    assert_select '[data-odontogram-entry]', text: /Composite restoration/
    post :create, params: { patient_id: @patient.id, operation: 'undo', revision: 1,
      editor_id: @editor, request_id: SecureRandom.uuid, change_id: @patient.odontogram_changes.sole.id }, as: :json
    assert_response :created
    assert_equal 'removed', entry.reload.state
    assert_equal 'Composite restoration', entry.treatment_snapshot['name']
  end

  test 'another practices preset cannot be applied to this patient' do
    other = practices(:trialing_practice).treatments.create!(name: 'Other practice', price: 20, odontogram_category: 'filling')
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count', 'Balance.count'] do
      add_preset(treatment_id: other.id, treatment_version: other.updated_at.utc.iso8601(6))
      assert_response :conflict
    end
  end

  test 'stale removed or mismatched presets cannot record a different treatment' do
    old_version = @treatment.updated_at.utc.iso8601(6)
    @treatment.update!(name: 'Renamed')
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      add_preset(treatment_version: old_version)
      assert_response :conflict
      add_preset(category: 'crown', surfaces: [])
      assert_response :conflict
      @treatment.update!(odontogram_category: nil)
      add_preset
      assert_response :conflict
      @treatment.destroy!
      add_preset
      assert_response :conflict
    end
    assert_equal 0, @patient.reload.odontogram_revision
  end

  test 'retry of a saved preset still succeeds after its catalogue record is deleted' do
    request_id = SecureRandom.uuid
    add_preset(request_id: request_id)
    assert_response :created
    @treatment.destroy!
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      add_preset(request_id: request_id)
    end
    assert_response :success
  end

  test 'different preset names cannot bypass duplicate marking protection' do
    add_preset
    other = @practice.treatments.create!(name: 'Another filling', price: 10, odontogram_category: 'filling')
    other.reload
    assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count'] do
      add_preset(treatment_id: other.id, treatment_version: other.updated_at.utc.iso8601(6))
    end
    assert_response :unprocessable_entity
  end

  test 'disabled chart retains saved treatment names but offers no presets' do
    add_preset
    @practice.update!(odontogram_enabled: false)
    get :show, params: { patient_id: @patient.id }, as: :json
    assert_equal [], response.parsed_body['presets']
    assert_equal 'Composite restoration', response.parsed_body['entries'].sole['treatment_snapshot']['name']
    assert_no_difference 'OdontogramEntry.count' do
      add_preset(tooth: 15)
    end
    assert_response :forbidden
  end
end
