# frozen_string_literal: true

module OdontogramBridge
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_bridge
    validate :validate_bridge
    validate :validate_bridge_dependencies
  end

  private

  def normalize_bridge
    return unless category == 'fixed_bridge' && bridge_units.is_a?(Array) && bridge_units.all? { |unit| unit.is_a?(Hash) }

    self.bridge_units = bridge_units.map(&:stringify_keys)
    row = self.class::ARCHES.find { |teeth| bridge_units.present? && bridge_units.all? { |unit| teeth.include?(unit['tooth']) } }
    return unless row && bridge_units.any? { |unit| unit['tooth'] == tooth }

    units = bridge_units.sort_by { |unit| row.index(unit['tooth']) }
    members = units.map { |unit| unit['tooth'] }
    return unless member_teeth == [] || member_teeth == members

    self.bridge_units = units
    self.member_teeth = members
    self.tooth = members.first
  end

  def validate_bridge
    unless category == 'fixed_bridge'
      errors.add(:base, I18n.t('odontogram.errors.bridge_units')) unless bridge_units == []
      return
    end

    valid_units = bridge_units.is_a?(Array) && bridge_units.size >= 2 && bridge_units.all? do |unit|
      unit.is_a?(Hash) && (unit.keys - %w[tooth role implant_entry_id]).empty? &&
        %w[natural_support implant_support pontic].include?(unit['role']) &&
        (unit['role'] == 'implant_support' ? unit['implant_entry_id'].is_a?(Integer) : unit['implant_entry_id'].nil?)
    end
    row = self.class::ARCHES.find { |teeth| teeth.include?(tooth) }
    valid = valid_units && row && member_teeth == bridge_units.map { |unit| unit['tooth'] } &&
      member_teeth.uniq == member_teeth && (member_teeth - row).empty? &&
      member_teeth == row[row.index(member_teeth.first)..row.index(member_teeth.last)] &&
      bridge_units.any? { |unit| unit['role'] == 'pontic' } && bridge_units.any? { |unit| unit['role'] != 'pontic' }
    errors.add(:base, I18n.t('odontogram.errors.bridge_units')) unless valid
    return unless valid && state == 'active' && patient

    peers = patient.odontogram_entries.present_in_mouth.where.not(id: id).touching_any(member_teeth).to_a
    overlap_peers = planned? ? marking_peers.touching_any(member_teeth).to_a : peers
    if overlap_peers.any? { |entry| %w[fixed_bridge complete_denture partial_denture].include?(entry.category) }
      errors.add(:base, I18n.t('odontogram.editor.bridge_overlap'))
    end
    if planned?
      implants = patient.odontogram_entries.active.where(category: 'implant', id: bridge_units.filter_map { |unit| unit['implant_entry_id'] }).to_a
      bridge_units.select { |unit| unit['role'] == 'implant_support' }.each do |unit|
        unless implants.any? { |implant| implant.id == unit['implant_entry_id'] && implant.tooth == unit['tooth'] }
          errors.add(:base, I18n.t('odontogram.editor.bridge_support', tooth: unit['tooth']))
        end
      end
      return
    end
    bridge_units.each do |unit|
      records = peers.select { |entry| entry.target_teeth.include?(unit['tooth']) }
      absent = records.any? { |entry| %w[missing edentulous_arch].include?(entry.category) }
      implant = records.find { |entry| entry.category == 'implant' }
      root = records.any? { |entry| entry.category == 'retained_root' }
      supported = case unit['role']
      when 'natural_support' then !absent && !implant && !root
      when 'implant_support' then implant && implant.id == unit['implant_entry_id']
      when 'pontic' then absent && !implant && !root
      end
      errors.add(:base, I18n.t('odontogram.editor.bridge_support', tooth: unit['tooth'])) unless supported
    end
  end

  def validate_bridge_dependencies
    return unless patient && category != 'fixed_bridge' && target_teeth.present?
    removing = state == 'removed' || (planned? && treatment_status_in_database == 'completed')
    return if planned? && !removing
    affected_categories = removing ? %w[missing edentulous_arch implant] : %w[missing edentulous_arch implant retained_root complete_denture partial_denture]
    return unless affected_categories.include?(category)

    bridges = patient.odontogram_entries.present_in_mouth.where(category: 'fixed_bridge').touching_any(target_teeth).to_a
    return if bridges.empty?

    remaining_absence = if removing && %w[missing edentulous_arch].include?(category)
      patient.odontogram_entries.present_in_mouth.where.not(id: id).where(category: %w[missing edentulous_arch])
        .touching_any(bridges.flat_map(&:target_teeth).uniq).to_a.flat_map(&:target_teeth).uniq
    end
    blocked = bridges.any? do |bridge|
      bridge.bridge_units.any? do |unit|
        next false unless target_teeth.include?(unit['tooth'])

        if removing
          if category == 'implant'
            unit['implant_entry_id'] == id
          elsif %w[missing edentulous_arch].include?(category) && unit['role'] == 'pontic'
            !remaining_absence.include?(unit['tooth'])
          end
        elsif %w[missing edentulous_arch].include?(category)
          unit['role'] == 'natural_support'
        elsif %w[implant retained_root].include?(category)
          unit['role'] != 'implant_support' || (category == 'implant' && unit['implant_entry_id'] != id)
        elsif self.class::DENTURE_CATEGORIES.include?(category)
          true
        end
      end
    end
    errors.add(:base, I18n.t('odontogram.editor.bridge_dependency')) if blocked
  end
end
