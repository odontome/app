# frozen_string_literal: true

require 'test_helper'

class OdontogramEntryTest < ActiveSupport::TestCase
  test 'every catalogue category has a reviewed entry mode shared with the browser checks' do
    modes = JSON.parse(File.read(Rails.root.join('test/fixtures/files/odontogram_entry_modes.json')))
    assert_equal OdontogramEntry::CATEGORIES.sort, modes.keys.sort
    assert_equal OdontogramEntry::SURFACE_CATEGORIES.sort, modes.select { |_category, mode| mode.start_with?('surface_') }.keys.sort
    assert_equal OdontogramEntry::OPTIONAL_SURFACE_CATEGORIES.sort, modes.select { |_category, mode| mode == 'surface_optional' }.keys.sort
    assert_equal OdontogramEntry::PAIRED_CATEGORIES.sort, modes.select { |_category, mode| %w[neighbor_pair arch_pair].include?(mode) }.keys.sort
    assert_equal OdontogramEntry::GROUP_CATEGORIES.sort, modes.select { |_category, mode| %w[attachment_set continuous_region].include?(mode) }.keys.sort
    assert_equal OdontogramEntry::ARCH_CATEGORIES.sort, modes.select { |_category, mode| %w[whole_arch complete_prosthesis replacement_set].include?(mode) }.keys.sort
  end

  setup do
    @entry = patients(:one).odontogram_entries.build(category: 'caries', tooth: 16, surfaces: ['O'],
      recorded_by: users(:founder), recorded_by_name: users(:founder).fullname)
  end

  test 'all permanent and primary tooth identities accept their appropriate central surface' do
    assert_equal 52, OdontogramEntry::TEETH.size
    OdontogramEntry::TEETH.each do |tooth|
      @entry.tooth = tooth
      @entry.surfaces = [tooth % 10 <= 3 ? 'I' : 'O']
      assert @entry.valid?, "#{tooth}: #{@entry.errors.full_messages}"
    end
  end

  test 'all surface families accept single and grouped entries while rejecting exact duplicates' do
    OdontogramEntry::SURFACE_CATEGORIES.each do |category|
      single = patients(:one).odontogram_entries.create!(category: category, tooth: 16, surfaces: ['O'], recorded_by_name: 'Sample')
      group = patients(:one).odontogram_entries.create!(category: category, tooth: 16, surfaces: %w[M O], recorded_by_name: 'Sample')
      duplicate = patients(:one).odontogram_entries.build(category: category, tooth: 16, surfaces: %w[O M], recorded_by_name: 'Sample')
      assert_not duplicate.valid?, category
      assert_equal ['O'], single.reload.surfaces
      assert_equal %w[M O], group.reload.surfaces
    end
  end

  test 'invalid surface combinations and unknown categories cannot be stored' do
    [['I'], ['L'], ['O', 'O'], [], ['<script>']].each do |surfaces|
      @entry.surfaces = surfaces
      assert_not @entry.valid?
    end
    @entry.surfaces = ['O']
    @entry.category = 'invented'
    assert_not @entry.valid?
    @entry.category = 'crown'
    assert_not @entry.valid?
    @entry.surfaces = []
    assert @entry.valid?
  end

  test 'implant support must be active at the same patient and position and only supports crowns' do
    implant = patients(:one).odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    @entry.assign_attributes(category: 'crown', surfaces: [], implant_entry: implant)
    assert @entry.valid?
    @entry.tooth = 15
    assert_not @entry.valid?
    @entry.tooth = 16
    @entry.patient = patients(:three)
    assert_not @entry.valid?
    @entry.patient = patients(:one)
    @entry.category = 'rct'
    assert_not @entry.valid?
    @entry.category = 'crown'
    @entry.implant_entry = nil
    assert_not @entry.valid?
    @entry.implant_entry = implant
    implant.update!(state: 'removed')
    assert_not @entry.valid?
  end

  test 'removing and restoring implant support cannot leave an active crown without its implant' do
    implant = patients(:one).odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    @entry.assign_attributes(category: 'crown', surfaces: [], implant_entry: implant)
    @entry.save!
    assert_not implant.update(state: 'removed')
    assert_equal 'active', implant.reload.state
    @entry.update!(state: 'removed')
    implant.update!(state: 'removed')
    assert_not @entry.update(state: 'active')
    assert_equal 'removed', @entry.reload.state
    assert_equal implant.id, @entry.implant_entry_id
    implant.update!(state: 'active')
    @entry.update!(state: 'active')
    assert_equal implant.id, @entry.chart_attributes['implant_entry_id']
  end

  test 'every category follows the same rules at missing and implanted positions' do
    implant = patients(:one).odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    patients(:one).odontogram_entries.create!(category: 'missing', tooth: 17, surfaces: [], recorded_by_name: 'Sample')
    OdontogramEntry::CATEGORIES.each do |category|
      surfaces = %w[caries filling temporary_filling inlay wear].include?(category) ? ['O'] : []
      @entry.assign_attributes(category: category, tooth: 16, surfaces: surfaces, rotation_direction: nil,
        arch: OdontogramEntry::ARCH_CATEGORIES.include?(category) ? 'upper' : nil,
        member_teeth: OdontogramEntry::GROUP_CATEGORIES.include?(category) ? [16] : [],
        implant_entry: %w[crown temporary_crown mobility].include?(category) ? implant : nil)
      assert_equal %w[crown temporary_crown mobility missing removable_orthodontic edentulous_arch].include?(category), @entry.valid?, "implant: #{category}"
      @entry.assign_attributes(tooth: 17, implant_entry: nil, member_teeth: OdontogramEntry::GROUP_CATEGORIES.include?(category) ? [17] : [])
      assert_equal %w[implant retained_root removable_orthodontic edentulous_arch].include?(category), @entry.valid?, "missing: #{category}"
    end
  end

  test 'patient deletion removes crowns and their implant together' do
    patient = patients(:one)
    implant = patient.odontogram_entries.create!(category: 'implant', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    @entry.assign_attributes(category: 'crown', surfaces: [], implant_entry: implant)
    @entry.save!
    assert_difference 'OdontogramEntry.count', -2 do
      patient.destroy!
    end
  end

  test 'unknown observation date stays unknown and invalid or future dates are rejected' do
    assert_nil @entry.observed_on
    assert @entry.valid?
    @entry.observed_on = 'not a date'
    assert_not @entry.valid?
    @entry.observed_on = Date.tomorrow
    assert_not @entry.valid?
    @entry.observed_on = Date.yesterday
    assert @entry.valid?
  end

  test 'temporary work pulpotomy and wear enforce their tooth or surface targets' do
    %w[temporary_crown pulpotomy].each do |category|
      @entry.assign_attributes(category: category, surfaces: [])
      assert @entry.valid?, @entry.errors.full_messages.join(', ')
      @entry.surfaces = ['O']
      assert_not @entry.valid?
    end
    %w[temporary_filling wear].each do |category|
      OdontogramEntry::TEETH.each do |tooth|
        @entry.assign_attributes(category: category, tooth: tooth, surfaces: [tooth % 10 <= 3 ? 'I' : 'O'])
        assert @entry.valid?, "#{category} #{tooth}: #{@entry.errors.full_messages}"
        @entry.surfaces = []
        assert_not @entry.valid?
      end
    end
  end

  test 'recording attribution remains readable when the author account is removed' do
    author = User.create!(practice: practices(:complete), firstname: 'Sample', lastname: 'Author',
      email: 'odontogram-author@example.com', roles: 'user', password: 'password123')
    @entry.recorded_by = author
    @entry.recorded_by_name = author.fullname
    @entry.save!
    author.destroy!

    assert_nil @entry.reload.recorded_by_id
    assert_equal 'Sample Author', @entry.recorded_by_name
  end

  test 'new veneers belong to a tooth without requesting surface coverage' do
    OdontogramEntry::TEETH.each do |tooth|
      @entry.assign_attributes(tooth: tooth, category: 'veneer', surfaces: [])
      assert @entry.valid?, "#{tooth}: #{@entry.errors.full_messages}"
      @entry.surfaces = [tooth % 10 <= 3 ? 'F' : 'B']
      assert_not @entry.valid?
    end
  end

  test 'persisted veneers enforce the same tooth-only target as new veneers' do
    @entry.assign_attributes(category: 'veneer', surfaces: [])
    @entry.save!
    @entry.update_columns(surfaces: ['B'])
    @entry.reload
    assert_not @entry.valid?
  end

  test 'every category enforces its surface or tooth target across permanent and primary teeth' do
    required = %w[caries filling temporary_filling inlay wear]
    optional = %w[sealant enamel_defect deep_fissures]
    tooth_only = %w[veneer crown temporary_crown rct pulpotomy post core fracture missing implant macrodontia microdontia peg_shaped mobility extrusion intrusion rotation gemination impaction ectopic erupting abnormal_position retained_root diastema fusion transposition fixed_orthodontic removable_orthodontic edentulous_arch complete_denture partial_denture fixed_bridge]
    assert_equal OdontogramEntry::CATEGORIES.sort, (required + optional + tooth_only).sort
    OdontogramEntry::TEETH.each do |tooth|
      OdontogramEntry::CATEGORIES.each do |category|
        @entry.assign_attributes(tooth: tooth, category: category, surfaces: [], rotation_direction: nil,
          arch: OdontogramEntry::ARCH_CATEGORIES.include?(category) ? ([1,2,5,6].include?(tooth / 10) ? 'upper' : 'lower') : nil,
          member_teeth: OdontogramEntry::GROUP_CATEGORIES.include?(category) ? [tooth] : [],
          paired_tooth: OdontogramEntry::PAIRED_CATEGORIES.include?(category) ? OdontogramEntry.neighbors(tooth).first : nil,
          replacement_teeth: OdontogramEntry::DENTURE_CATEGORIES.include?(category) ? [tooth] : [], bridge_units: [])
        if category == 'fixed_bridge'
          neighbor = OdontogramEntry.neighbors(tooth).first
          absence = patients(:one).odontogram_entries.create!(category: 'missing', tooth: neighbor, surfaces: [], recorded_by_name: 'Sample')
          @entry.bridge_units = [{ tooth: tooth, role: 'natural_support' }, { tooth: neighbor, role: 'pontic' }]
        end
        if OdontogramEntry::DENTURE_CATEGORIES.include?(category)
          absence = patients(:one).odontogram_entries.create!(category: 'edentulous_arch', tooth: tooth, arch: @entry.arch, surfaces: [], recorded_by_name: 'Sample')
        end
        assert_equal !required.include?(category), @entry.valid?, "#{tooth} #{category} empty"
        @entry.surfaces = %w[M D]
        assert_equal !tooth_only.include?(category), @entry.valid?, "#{tooth} #{category} multiple"
        @entry.surfaces = [tooth % 10 <= 3 ? 'O' : 'I']
        assert_not @entry.valid?, "#{tooth} #{category} invalid anatomy"
        absence.update!(state: 'removed') if OdontogramEntry::DENTURE_CATEGORIES.include?(category) || category == 'fixed_bridge'
      end
    end
  end

  test 'enamel defects and deep fissures can retain an unspecified site and core remains tooth only' do
    %w[enamel_defect deep_fissures].each do |category|
      [[], ['O'], %w[M O]].each do |surfaces|
        @entry.assign_attributes(category: category, surfaces: surfaces)
        assert @entry.valid?, @entry.errors.full_messages.join(', ')
      end
    end
    @entry.assign_attributes(category: 'core', surfaces: [])
    assert @entry.valid?
    @entry.surfaces = ['O']
    assert_not @entry.valid?
  end
  test 'tooth size observations coexist with care but contradictory sizes need explicit correction' do
    @entry.assign_attributes(category: 'macrodontia', surfaces: [])
    @entry.save!
    small = @entry.patient.odontogram_entries.build(category: 'microdontia', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    assert_not small.valid?
    assert_includes small.errors.full_messages, I18n.t('odontogram.errors.tooth_size_conflict')
    filling = @entry.patient.odontogram_entries.create!(category: 'filling', tooth: 16, surfaces: ['O'], recorded_by_name: 'Sample')
    assert_equal 'active', @entry.reload.state
    @entry.update!(state: 'removed')
    small.save!
    assert_not @entry.update(state: 'active')
    small.update!(state: 'removed')
    @entry.reload.update!(state: 'active')
    assert_equal 'active', filling.reload.state
  end

  test 'peg shape can coexist with a size observation and restoration without implying either' do
    @entry.assign_attributes(category: 'peg_shaped', tooth: 22, surfaces: [])
    @entry.save!
    assert_equal ['peg_shaped'], @entry.patient.odontogram_entries.active.pluck(:category)
    small = @entry.patient.odontogram_entries.create!(category: 'microdontia', tooth: 22, surfaces: [], recorded_by_name: 'Sample')
    crown = @entry.patient.odontogram_entries.create!(category: 'crown', tooth: 22, surfaces: [], recorded_by_name: 'Sample')
    @entry.update!(state: 'removed')
    assert_equal 'active', small.reload.state
    assert_equal 'active', crown.reload.state
    @entry.update!(state: 'active')
    assert_equal 3, @entry.patient.odontogram_entries.active.count
  end

  test 'opposite vertical positions require explicit correction and preserve other markings' do
    @entry.assign_attributes(category: 'extrusion', surfaces: [])
    @entry.save!
    opposite = @entry.patient.odontogram_entries.build(category: 'intrusion', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    assert_not opposite.valid?
    assert_includes opposite.errors.full_messages, I18n.t('odontogram.errors.vertical_position_conflict')
    crown = @entry.patient.odontogram_entries.create!(category: 'crown', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    @entry.update!(state: 'removed')
    opposite.save!
    assert_not @entry.update(state: 'active')
    opposite.update!(state: 'removed')
    @entry.reload.update!(state: 'active')
    assert_equal 'active', crown.reload.state
  end

  test 'position directions match the arch across permanent and primary teeth' do
    OdontogramEntry::TEETH.each do |tooth|
      upper = [1, 2, 5, 6].include?(tooth / 10)
      @entry.assign_attributes(category: 'abnormal_position', tooth: tooth, surfaces: [], position_directions: ['M', upper ? 'P' : 'L'])
      assert @entry.valid?, "#{tooth}: #{@entry.errors.full_messages}"
      @entry.position_directions = [upper ? 'L' : 'P']
      assert_not @entry.valid?, "#{tooth}: wrong arch"
    end
  end

  test 'retained roots require explicit correction of crown findings and allow root observations' do
    root = @entry.patient.odontogram_entries.create!(category: 'retained_root', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    incompatible = %w[caries enamel_defect deep_fissures filling temporary_filling sealant inlay wear veneer crown temporary_crown pulpotomy core fracture peg_shaped erupting implant]
    incompatible.each do |category|
      surfaces = %w[caries filling temporary_filling inlay wear].include?(category) ? ['O'] : []
      @entry.assign_attributes(category: category, surfaces: surfaces)
      assert_not @entry.valid?, category
    end
    %w[rct mobility].each do |category|
      @entry.assign_attributes(category: category, surfaces: [])
      assert @entry.valid?, category
    end
    root.update!(state: 'removed')
    @entry.assign_attributes(category: 'crown', surfaces: [])
    @entry.save!
    assert_not root.update(state: 'active')
    @entry.update!(state: 'removed')
    root.reload.update!(state: 'active')
  end

  test 'a missing tooth may retain a root without inferring an extraction or an implant' do
    @entry.assign_attributes(category: 'retained_root', surfaces: [])
    @entry.save!
    missing = @entry.patient.odontogram_entries.create!(category: 'missing', tooth: 16, surfaces: [], recorded_by_name: 'Sample')
    assert_equal %w[missing retained_root], @entry.patient.odontogram_entries.active.order(:category).pluck(:category)
    @entry.update!(state: 'removed')
    assert_equal 'active', missing.reload.state
    @entry.update!(state: 'active')
  end

  test 'every neighboring pair normalizes consistently across both permanent and primary arches' do
    arches = [
      [18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28],
      [48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38],
      [55,54,53,52,51,61,62,63,64,65], [85,84,83,82,81,71,72,73,74,75]
    ]
    arches.each do |arch|
      arch.each_cons(2) do |first, second|
        @entry.assign_attributes(category: 'diastema', tooth: second, paired_tooth: first, surfaces: [])
        assert @entry.valid?, "#{first}–#{second}: #{@entry.errors.full_messages}"
        assert_equal [first, second], [@entry.tooth, @entry.paired_tooth]
      end
    end
  end

  test 'gemination keeps one tooth identity and does not infer size or overwrite care' do
    @entry.assign_attributes(category: 'gemination', tooth: 22, surfaces: [])
    @entry.save!
    assert_equal ['gemination'], @entry.patient.odontogram_entries.pluck(:category)
    crown = @entry.patient.odontogram_entries.create!(category: 'crown', tooth: 22, surfaces: [], recorded_by_name: 'Sample')
    @entry.update!(state: 'removed')
    assert_equal 'active', crown.reload.state
    @entry.update!(state: 'active')
    assert_equal [22], @entry.patient.odontogram_entries.active.distinct.pluck(:tooth)
  end

end
