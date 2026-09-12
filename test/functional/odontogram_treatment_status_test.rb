# frozen_string_literal: true
require 'test_helper'

class OdontogramTreatmentStatusTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
  end

  def change(entry = {}, **operation)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { tooth: 16, category: 'crown', surfaces: [], treatment_status: 'planned' }.merge(entry) }.merge(operation), as: :json
  end

  test 'planned crown completes on the same record and undo restores its plan and saved history' do
    change
    assert_response :created
    entry = @patient.odontogram_entries.sole
    assert_equal 'planned', entry.chart_attributes['treatment_status']
    planned = @patient.odontogram_changes.sole
    request = SecureRandom.uuid
    change({}, operation: 'complete', entry_id: entry.id, request_id: request)
    assert_response :created
    completed = @patient.odontogram_changes.recent.first
    assert_equal 'completed', entry.reload.treatment_status
    assert_not_nil entry.completed_at
    assert_equal 'planned', planned.chart_entries.sole['treatment_status']
    assert_equal 'completed', completed.chart_entries.sole['treatment_status']
    assert_equal 1, @patient.odontogram_entries.count
    change({}, operation: 'complete', entry_id: entry.id, request_id: request)
    assert_response :ok
    assert_equal 2, @patient.odontogram_changes.count
    change({}, operation: 'undo', change_id: completed.id)
    assert_response :created
    assert_equal 'planned', entry.reload.treatment_status
    assert_nil entry.completed_at
  end

  test 'planned implant does not replace a natural tooth or support existing work' do
    change({ category: 'implant' })
    assert_response :created
    implant = @patient.odontogram_entries.sole
    change({ treatment_status: 'existing' })
    assert_response :created
    crown = @patient.odontogram_entries.find_by!(category: 'crown')
    assert_nil crown.implant_entry_id
    change({}, operation: 'complete', entry_id: implant.id)
    assert_response :unprocessable_entity
    assert_equal 'planned', implant.reload.treatment_status
    assert_equal 2, @patient.odontogram_changes.count
  end

  test 'existing and planned crowns coexist but duplicates and conflicting completion are rejected' do
    change({ treatment_status: 'existing' })
    assert_response :created
    change
    assert_response :created
    planned = @patient.odontogram_entries.recent.first
    change
    assert_response :unprocessable_entity
    change({}, operation: 'complete', entry_id: planned.id)
    assert_response :unprocessable_entity
    assert_equal 'planned', planned.reload.treatment_status
  end

  test 'findings cannot be planned or completed and completion dates cannot be forged' do
    change({ category: 'caries', surfaces: ['O'] })
    assert_response :unprocessable_entity
    change({ treatment_status: 'completed', completed_at: 1.day.ago })
    assert_response :unprocessable_entity
    change({ category: 'caries', surfaces: ['O'], treatment_status: 'existing' })
    assert_response :created
    change({}, operation: 'complete', entry_id: @patient.odontogram_entries.sole.id)
    assert_response :conflict
  end

  test 'completion obeys practice flag and revision checks' do
    change
    entry = @patient.odontogram_entries.sole
    change({}, operation: 'complete', entry_id: entry.id, revision: 0)
    assert_response :conflict
    practices(:complete).update!(odontogram_enabled: false)
    change({}, operation: 'complete', entry_id: entry.id)
    assert_response :forbidden
  end

  test 'every treatment family can be planned and completed with its own target rules' do
    categories = %w[filling temporary_filling sealant inlay veneer crown temporary_crown rct pulpotomy post core implant fixed_orthodontic removable_orthodontic complete_denture partial_denture fixed_bridge]
    assert_equal categories, OdontogramEntry::TREATMENT_CATEGORIES
    categories.each do |category|
      ActiveRecord::Base.transaction(requires_new: true) do
        attrs = { category: category, surfaces: OdontogramEntry::SURFACE_CATEGORIES.include?(category) ? ['M', 'O'] : [] }
        attrs[:member_teeth] = [16, 15] if OdontogramEntry::GROUP_CATEGORIES.include?(category)
        if OdontogramEntry::DENTURE_CATEGORIES.include?(category)
          attrs.merge!(arch: 'upper', replacement_teeth: [16, 15])
        elsif category == 'fixed_bridge'
          attrs[:bridge_units] = [{ tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }]
        end
        change(attrs)
        assert_response :created, category
        entry = @patient.odontogram_entries.recent.first
        assert_equal 'planned', entry.treatment_status, category
        change(attrs)
        assert_response :unprocessable_entity, "duplicate #{category}"
        if %w[complete_denture partial_denture fixed_bridge].include?(category)
          change({}, operation: 'complete', entry_id: entry.id)
          assert_response :unprocessable_entity, "missing support for #{category}"
          absent = category == 'complete_denture' ? { category: 'edentulous_arch', arch: 'upper', tooth: 16 } : { category: 'missing', tooth: 15 }
          @patient.odontogram_entries.create!(absent.merge(surfaces: [], recorded_by_name: 'Sample'))
          if category == 'partial_denture'
            @patient.odontogram_entries.create!(category: 'missing', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
          end
        end
        change({}, operation: 'complete', entry_id: entry.id)
        assert_response :created, category
        assert_equal 'completed', entry.reload.treatment_status, category
        change({}, operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
        assert_response :created, category
        assert_equal 'planned', entry.reload.treatment_status, category
        raise ActiveRecord::Rollback
      end
    end
  end

  test 'completion preserves findings and custom treatment names' do
    finding = @patient.odontogram_entries.create!(category: 'caries', tooth: 16, surfaces: ['O'], recorded_by_name: 'Sample')
    treatment = treatments(:complete)
    treatment.update!(odontogram_category: 'filling')
    change({ category: 'filling', surfaces: ['O'], treatment_id: treatment.id, treatment_version: treatment.updated_at.utc.iso8601(6) })
    assert_response :created
    entry = @patient.odontogram_entries.recent.first
    snapshot = entry.treatment_snapshot
    change({}, operation: 'complete', entry_id: entry.id)
    assert_response :created
    assert_equal snapshot, entry.reload.treatment_snapshot
    assert_equal 'active', finding.reload.state
  end

  test 'undoing implant completion cannot invalidate an existing supported crown' do
    change({ category: 'implant' })
    implant = @patient.odontogram_entries.sole
    change({}, operation: 'complete', entry_id: implant.id)
    assert_response :created
    @patient.odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], implant_entry: implant, recorded_by_name: 'Sample')
    change({}, operation: 'undo', change_id: @patient.odontogram_changes.recent.first.id)
    assert_response :unprocessable_entity
    assert_equal 'completed', implant.reload.treatment_status
  end

  test 'another patients treatment cannot be completed' do
    entry = patients(:three).odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], treatment_status: 'planned', recorded_by_name: 'Sample')
    assert_raises(ActiveRecord::RecordNotFound) { change({}, operation: 'complete', entry_id: entry.id) }
    assert_equal 'planned', entry.reload.treatment_status
  end
end
