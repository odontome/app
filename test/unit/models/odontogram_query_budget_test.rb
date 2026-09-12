# frozen_string_literal: true
require 'test_helper'

class OdontogramQueryBudgetTest < ActiveSupport::TestCase
  def queries
    captured = []
    subscriber = ->(_name, _start, _finish, _id, payload) do
      captured << payload[:sql] if payload[:sql].match?(/\ASELECT/i) && payload[:sql].include?('odontogram_') && payload[:name] != 'SCHEMA'
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') { yield }
    end
    captured
  end

  def arch_with_bridge(patient, members)
    absence = patient.odontogram_entries.create!(category: 'edentulous_arch', arch: 'upper', tooth: 13, surfaces: [], recorded_by_name: 'Sample')
    units = members.map.with_index do |tooth, index|
      if index == 0 || index == members.size - 1
        implant = patient.odontogram_entries.create!(category: 'implant', tooth: tooth, surfaces: [], recorded_by_name: 'Sample')
        { tooth: tooth, role: 'implant_support', implant_entry_id: implant.id }
      else
        patient.odontogram_entries.create!(category: 'missing', tooth: tooth, surfaces: [], recorded_by_name: 'Sample')
        { tooth: tooth, role: 'pontic' }
      end
    end
    patient.odontogram_entries.create!(category: 'fixed_bridge', tooth: members.first, bridge_units: units, surfaces: [], recorded_by_name: 'Sample')
    absence.state = 'removed'
    queries { assert absence.valid?, absence.errors.full_messages.join(', ') }
  end

  test 'absence dependency query count does not grow with bridge units' do
    small = arch_with_bridge(patients(:one), [16,15,14])
    large = arch_with_bridge(patients(:three), OdontogramEntry::ARCHES.first)
    assert_operator large.size, :<=, small.size, "3 units: #{small.size} SELECTs; 16 units: #{large.size} SELECTs"
    assert_operator large.size, :<=, 4
  end

  test 'absence dependency query count does not grow with separate partial dentures' do
    counts = [patients(:one), patients(:three)].each_with_index.map do |patient, index|
      absence = patient.odontogram_entries.create!(category: 'edentulous_arch', arch: 'upper', tooth: 13, surfaces: [], recorded_by_name: 'Sample')
      OdontogramEntry::ARCHES.first.first(index.zero? ? 1 : 12).each do |tooth|
        patient.odontogram_entries.create!(category: 'missing', tooth: tooth, surfaces: [], recorded_by_name: 'Sample')
        patient.odontogram_entries.create!(category: 'partial_denture', arch: 'upper', tooth: tooth, replacement_teeth: [tooth], surfaces: [], recorded_by_name: 'Sample')
      end
      absence.state = 'removed'
      queries { assert absence.valid?, absence.errors.full_messages.join(', ') }.size
    end
    assert_operator counts.last, :<=, counts.first, "1 denture: #{counts.first} SELECTs; 12 dentures: #{counts.last} SELECTs"
    assert_operator counts.last, :<=, 4
  end

  test 'a routine filling has a small fixed validation query budget' do
    entry = patients(:one).odontogram_entries.build(category: 'filling', tooth: 16, surfaces: ['O'], recorded_by_name: 'Sample')
    captured = queries { assert entry.valid? }
    assert_operator captured.size, :<=, 3, "Filling validation used #{captured.size} SELECTs"
  end
end
