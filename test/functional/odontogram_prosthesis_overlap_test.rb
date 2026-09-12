# frozen_string_literal: true
require 'test_helper'

class OdontogramProsthesisOverlapTest < ActionController::TestCase
  tests OdontogramsController

  setup do
    @controller.session['user'] = users(:founder)
    @patient = patients(:one)
    practices(:complete).update!(odontogram_enabled: true)
    @editor = SecureRandom.uuid
    @bridge = { category: 'fixed_bridge', tooth: 16,
      bridge_units: [{ tooth: 16, role: 'natural_support' }, { tooth: 15, role: 'pontic' }] }
  end

  def add(entry)
    post :create, params: { patient_id: @patient.id, request_id: SecureRandom.uuid, editor_id: @editor,
      revision: @patient.reload.odontogram_revision, operation: 'add',
      odontogram_entry: { surfaces: [], treatment_status: 'planned' }.merge(entry) }, as: :json
  end

  %w[partial_denture complete_denture].each do |category|
    %w[bridge_first denture_first].each do |order|
      test "planned #{category} and bridge reject overlap with #{order}" do
        denture = { category: category, tooth: 15, arch: 'upper', replacement_teeth: [15] }
        first, second = order == 'bridge_first' ? [@bridge, denture] : [denture, @bridge]
        add(first)
        assert_response :created
        original = @patient.odontogram_entries.sole.chart_attributes

        assert_no_difference ['OdontogramEntry.count', 'OdontogramChange.count', -> { @patient.reload.odontogram_revision }] do
          add(second)
          assert_response :unprocessable_entity
        end
        assert_equal original, @patient.odontogram_entries.sole.chart_attributes
      end
    end
  end

  test 'disjoint partial denture and bridge plans in one arch remain independent in either order' do
    denture = { category: 'partial_denture', tooth: 14, arch: 'upper', replacement_teeth: [14] }
    [[@bridge, denture], [denture, @bridge]].each do |ordered|
      ActiveRecord::Base.transaction(requires_new: true) do
        ordered.each do |entry|
          add(entry)
          assert_response :created
        end
        assert_equal 2, @patient.odontogram_entries.active.count
        raise ActiveRecord::Rollback
      end
    end
  end

  test 'a complete denture plan blocks its whole arch but leaves the opposite arch available' do
    add(@bridge)
    assert_response :created
    add(category: 'complete_denture', tooth: 14, arch: 'upper', replacement_teeth: [14])
    assert_response :unprocessable_entity
    add(category: 'complete_denture', tooth: 44, arch: 'lower', replacement_teeth: [44])
    assert_response :created
  end

  test 'planned dentures and bridges may overlap current work in either order' do
    @patient.odontogram_entries.create!(category: 'edentulous_arch', tooth: 16, arch: 'upper', recorded_by_name: 'Sample')
    implant = @patient.odontogram_entries.create!(category: 'implant', tooth: 16, recorded_by_name: 'Sample')
    bridge = @bridge.merge(bridge_units: [{ tooth: 16, role: 'implant_support', implant_entry_id: implant.id }, { tooth: 15, role: 'pontic' }])
    %w[partial_denture complete_denture].each do |category|
      denture = { category: category, tooth: 15, arch: 'upper', replacement_teeth: [15] }
      [[bridge, denture], [denture, bridge]].each do |first, second|
        %w[existing planned].each do |first_status|
          ActiveRecord::Base.transaction(requires_new: true) do
            add(first.merge(treatment_status: first_status))
            assert_response :created
            add(second.merge(treatment_status: first_status == 'planned' ? 'existing' : 'planned'))
            assert_response :created
            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end
end
