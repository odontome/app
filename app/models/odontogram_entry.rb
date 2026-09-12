# frozen_string_literal: true

class OdontogramEntry < ApplicationRecord
  CATEGORIES = %w[caries enamel_defect deep_fissures filling temporary_filling sealant inlay veneer crown temporary_crown rct pulpotomy post core fracture wear missing implant macrodontia microdontia peg_shaped mobility extrusion intrusion rotation gemination impaction ectopic erupting abnormal_position retained_root diastema fusion transposition fixed_orthodontic removable_orthodontic edentulous_arch complete_denture partial_denture fixed_bridge].freeze
  TREATMENT_CATEGORIES = %w[filling temporary_filling sealant inlay veneer crown temporary_crown rct pulpotomy post core implant fixed_orthodontic removable_orthodontic complete_denture partial_denture fixed_bridge].freeze
  ARCH_CATEGORIES = %w[edentulous_arch complete_denture partial_denture].freeze
  DENTURE_CATEGORIES = %w[complete_denture partial_denture].freeze
  PAIRED_CATEGORIES = %w[diastema fusion transposition].freeze
  GROUP_CATEGORIES = %w[fixed_orthodontic removable_orthodontic].freeze
  ATTACHMENT_CONFLICTS = %w[missing implant retained_root edentulous_arch].freeze
  ROTATION_DIRECTIONS = %w[unspecified clockwise counterclockwise].freeze
  SURFACE_CATEGORIES = %w[caries filling temporary_filling sealant inlay wear enamel_defect deep_fissures].freeze
  OPTIONAL_SURFACE_CATEGORIES = %w[sealant enamel_defect deep_fissures].freeze
  RETAINED_ROOT_CONFLICTS = (SURFACE_CATEGORIES + %w[veneer crown temporary_crown pulpotomy core fracture peg_shaped erupting diastema fusion transposition fixed_orthodontic]).freeze
  IMPLANT_SUPPORTED_CATEGORIES = %w[crown temporary_crown mobility].freeze
  TEETH = ([1, 2, 3, 4].flat_map { |quadrant| (1..8).map { |position| quadrant * 10 + position } } +
           [5, 6, 7, 8].flat_map { |quadrant| (1..5).map { |position| quadrant * 10 + position } }).freeze

  ARCHES = [
    [18,17,16,15,14,13,12,11,21,22,23,24,25,26,27,28],
    [48,47,46,45,44,43,42,41,31,32,33,34,35,36,37,38],
    [55,54,53,52,51,61,62,63,64,65],
    [85,84,83,82,81,71,72,73,74,75]
  ].map(&:freeze).freeze

  ARCH_TEETH = { 'upper' => (ARCHES[0] + ARCHES[2]).freeze, 'lower' => (ARCHES[1] + ARCHES[3]).freeze }.freeze

  def self.edentulous_conflicts(entries, arch)
    members = ARCH_TEETH.fetch(arch)
    entries.select do |entry|
      entry.state == 'active' && !entry.planned? && (entry.target_teeth & members).any? &&
        !(entry.category == 'fixed_bridge' && entry.bridge_units.none? { |unit| unit['role'] == 'natural_support' }) &&
        !%w[missing implant retained_root removable_orthodontic complete_denture partial_denture].include?(entry.category) &&
        !(IMPLANT_SUPPORTED_CATEGORIES.include?(entry.category) && entry.implant_entry_id.present?)
    end
  end

  def self.neighbors(tooth)
    arch = ARCHES.find { |row| row.include?(tooth) }
    return [] unless arch

    index = arch.index(tooth)
    [index.positive? ? arch[index - 1] : nil, arch[index + 1]].compact
  end

  def self.pair_candidates(tooth, category)
    return neighbors(tooth) unless category == 'transposition'

    (ARCHES.find { |row| row.include?(tooth) } || []) - [tooth]
  end

  include OdontogramBridge

  belongs_to :patient
  belongs_to :recorded_by, class_name: 'User', optional: true
  belongs_to :implant_entry, class_name: 'OdontogramEntry', optional: true
  has_many :implant_markings, class_name: 'OdontogramEntry', foreign_key: :implant_entry_id
  has_many :odontogram_changes, dependent: :delete_all

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(state: 'active') }
  scope :present_in_mouth, -> { active.where.not(treatment_status: 'planned') }
  scope :touching, ->(tooth) { where('tooth = :tooth OR paired_tooth = :tooth OR :tooth = ANY(member_teeth)', tooth: tooth) }

  scope :touching_any, ->(teeth) { where('tooth IN (:teeth) OR paired_tooth IN (:teeth) OR member_teeth && ARRAY[:teeth]::integer[]', teeth: teeth) }

  validates :recorded_by_name, presence: true, length: { maximum: 100 }
  validates :treatment_status, inclusion: { in: %w[existing planned completed] }
  validate :validate_treatment_status
  validates :state, inclusion: { in: %w[active removed] }
  before_validation :normalize_arch
  validate :validate_arch
  validate :validate_replacement_teeth
  before_validation :normalize_members
  validate :validate_members
  before_validation :normalize_pair
  before_validation :normalize_mobility_details
  before_validation :set_rotation_direction
  validate :validate_pair
  validate :validate_position_directions
  validate :validate_rotation_direction
  validate :validate_mobility_details
  validate :validate_chart_target
  validate :validate_observation_date
  validate :validate_current_marking
  validate :validate_tooth_size
  validate :validate_vertical_position
  validate :validate_retained_root
  validate :validate_support

  def chart_attributes
    attributes = as_json(only: %i[id tooth category surfaces observed_on state created_at recorded_by_name treatment_status completed_at])
    attributes['treatment_snapshot'] = treatment_snapshot if treatment_snapshot.present?
    attributes['implant_entry_id'] = implant_entry_id if implant_entry_id.present?
    attributes['mobility_grade'] = mobility_grade if mobility_grade.present?
    attributes['mobility_scale'] = mobility_scale if mobility_scale.present?
    attributes['rotation_direction'] = rotation_direction if rotation_direction.present?
    attributes['member_teeth'] = member_teeth if GROUP_CATEGORIES.include?(category) || ARCH_CATEGORIES.include?(category) || category == 'fixed_bridge'
    attributes['arch'] = arch if ARCH_CATEGORIES.include?(category)
    attributes['replacement_teeth'] = replacement_teeth if DENTURE_CATEGORIES.include?(category)
    attributes['bridge_units'] = bridge_units if category == 'fixed_bridge'
    attributes['paired_tooth'] = paired_tooth if paired_tooth.present?
    attributes['position_directions'] = position_directions if category == 'abnormal_position'
    attributes
  end

  def marking_name
    category_name = I18n.t("odontogram.categories.#{category}")
    name = treatment_snapshot.present? ? "#{treatment_snapshot.fetch('name')} (#{category_name})" : category_name
    name = "#{name} · #{I18n.t('odontogram.editor.replacement_positions', teeth: replacement_teeth.join(', '))}" if replacement_teeth.present?
    if category == 'fixed_bridge'
      roles = bridge_units.map { |unit| "#{unit['tooth']}: #{I18n.t("odontogram.editor.bridge_roles.#{unit['role']}")}" }
      name = "#{name} · #{roles.join(', ')}"
    end
    name = "#{name} · #{mobility_grade} (#{mobility_scale})" if mobility_grade.present?
    name = "#{name} · #{I18n.t("odontogram.editor.rotation_directions.#{rotation_direction}")}" if rotation_direction.present?
    if position_directions.present?
      directions = position_directions.map { |direction| I18n.t("odontogram.editor.position_directions.#{direction}") }
      name = "#{name} · #{directions.join(' · ')}"
    end
    name = "#{name} · #{I18n.t("odontogram.editor.treatment_statuses.#{treatment_status}")}" if TREATMENT_CATEGORIES.include?(category)
    implant_entry_id.present? ? "#{name} · #{I18n.t('odontogram.editor.on_implant')}" : name
  end

  def target_teeth
    member_teeth.present? ? member_teeth : [tooth, paired_tooth].compact
  end

  def target_name
    return I18n.t("odontogram.editor.arches.#{arch}") if ARCH_CATEGORIES.include?(category)

    return I18n.t('odontogram.teeth', numbers: member_teeth.join(', ')) if member_teeth.present?

    paired_tooth ? I18n.t('odontogram.teeth', numbers: "#{tooth}–#{paired_tooth}") : I18n.t('odontogram.tooth', number: tooth)
  end

  def planned?
    treatment_status == 'planned'
  end

  private

  def validate_treatment_status
    valid = TREATMENT_CATEGORIES.include?(category) || treatment_status == 'existing'
    valid &&= treatment_status == 'completed' ? completed_at.present? && completed_at <= Time.current : completed_at.nil?
    errors.add(:base, I18n.t('odontogram.errors.treatment_status')) unless valid
  end

  # Plans can overlap current work, but cannot duplicate another plan.
  def marking_peers
    peers = patient.odontogram_entries.active.where.not(id: id)
    planned? ? peers.where(treatment_status: 'planned') : peers.where.not(treatment_status: 'planned')
  end

  def normalize_arch
    return unless ARCH_CATEGORIES.include?(category) && ARCH_TEETH.key?(arch)

    members = ARCH_TEETH.fetch(arch)
    if category == 'partial_denture'
      return unless replacement_teeth.present? && (replacement_teeth - members).empty? && members.include?(tooth)

      members = replacement_teeth.sort_by { |number| members.index(number) }
      self.replacement_teeth = members
    end
    return unless (category == 'partial_denture' || members.include?(tooth)) && (member_teeth == [] || member_teeth == members)

    self.member_teeth = members
    self.tooth = members.first
  end

  def validate_arch
    members = category == 'partial_denture' ? replacement_teeth : ARCH_TEETH[arch]
    valid = ARCH_CATEGORIES.include?(category) ? ARCH_TEETH.key?(arch) && member_teeth.present? && member_teeth == members && tooth == member_teeth.first : arch.nil?
    errors.add(:base, I18n.t(category == 'partial_denture' ? 'odontogram.errors.replacement_teeth' : 'odontogram.errors.arch')) unless valid
    return unless valid && category == 'edentulous_arch' && state == 'active' && patient

    conflicts = self.class.edentulous_conflicts(patient.odontogram_entries.present_in_mouth.where.not(id: id), arch)
    errors.add(:base, I18n.t('odontogram.editor.arch_conflict')) if conflicts.any?
  end

  def validate_replacement_teeth
    unless DENTURE_CATEGORIES.include?(category)
      errors.add(:base, I18n.t('odontogram.errors.replacement_teeth')) unless replacement_teeth == []
      return
    end
    row = ARCHES.find { |teeth| replacement_teeth.present? && (replacement_teeth - teeth).empty? }
    valid = row && replacement_teeth.uniq == replacement_teeth && ARCH_TEETH.key?(arch) && (replacement_teeth - ARCH_TEETH[arch]).empty?
    errors.add(:base, I18n.t('odontogram.errors.replacement_teeth')) unless valid
    return unless valid && state == 'active' && patient

    self.replacement_teeth = row.select { |tooth| replacement_teeth.include?(tooth) }
    peers = marking_peers.where(arch: arch)
    absent_arch = peers.exists?(category: 'edentulous_arch')
    absent_teeth = patient.odontogram_entries.present_in_mouth.where(category: 'missing').pluck(:tooth)
    absence_recorded = category == 'complete_denture' ? absent_arch : absent_arch || (replacement_teeth - absent_teeth).empty?
    errors.add(:base, I18n.t(category == 'complete_denture' ? 'odontogram.editor.denture_absence' : 'odontogram.editor.partial_absence')) unless planned? || absence_recorded
    overlap = marking_peers.where(category: DENTURE_CATEGORIES + ['fixed_bridge']).touching_any(target_teeth).exists?
    errors.add(:base, I18n.t('odontogram.editor.denture_overlap')) if overlap
  end

  def normalize_members
    return unless GROUP_CATEGORIES.include?(category) && member_teeth.is_a?(Array)

    arch = ARCHES.find { |row| row.include?(tooth) }
    return unless arch && member_teeth.include?(tooth) && (member_teeth - arch).empty?

    self.member_teeth = member_teeth.sort_by { |number| arch.index(number) }
    self.tooth = member_teeth.first
  end

  def validate_members
    arch = ARCHES.find { |row| row.include?(tooth) }
    valid = if GROUP_CATEGORIES.include?(category)
      member_teeth.is_a?(Array) && member_teeth.present? && member_teeth.uniq == member_teeth &&
        member_teeth.include?(tooth) && arch && (member_teeth - arch).empty?
    elsif category == 'fixed_bridge'
      bridge_units.is_a?(Array) && bridge_units.all? { |unit| unit.is_a?(Hash) } && member_teeth.present? && member_teeth == bridge_units.map { |unit| unit['tooth'] }
    elsif ARCH_CATEGORIES.include?(category)
      ARCH_TEETH.key?(self.arch) && member_teeth == (category == 'partial_denture' ? replacement_teeth : ARCH_TEETH[self.arch])
    else
      member_teeth == []
    end
    if valid && category == 'removable_orthodontic'
      valid = member_teeth == arch[arch.index(member_teeth.first)..arch.index(member_teeth.last)]
    end
    errors.add(:base, I18n.t(category == 'removable_orthodontic' ? 'odontogram.errors.removable_extent' : 'odontogram.errors.member_teeth')) unless valid
    return unless valid && GROUP_CATEGORIES.include?(category) && state == 'active' && patient

    if marking_peers.where(category: category)
        .where('member_teeth && ARRAY[?]::integer[]', member_teeth).exists?
      errors.add(:base, I18n.t('odontogram.editor.appliance_overlap'))
    end
    if !planned? && category == 'fixed_orthodontic' && patient.odontogram_entries.present_in_mouth.touching_any(member_teeth).where(category: ATTACHMENT_CONFLICTS).exists?
      errors.add(:base, I18n.t('odontogram.errors.attachment_support'))
    end
  end

  def normalize_pair
    return unless PAIRED_CATEGORIES.include?(category) && self.class.pair_candidates(tooth, category).include?(paired_tooth)

    arch = ARCHES.find { |row| row.include?(tooth) }
    self.tooth, self.paired_tooth = [tooth, paired_tooth].sort_by { |number| arch.index(number) }
  end

  def validate_pair
    valid = PAIRED_CATEGORIES.include?(category) ? self.class.pair_candidates(tooth, category).include?(paired_tooth) : paired_tooth.nil?
    errors.add(:base, I18n.t(category == 'transposition' ? 'odontogram.errors.transposition_pair' : 'odontogram.errors.paired_tooth')) unless valid
    return unless valid && PAIRED_CATEGORIES.include?(category) && state == 'active' && patient

    opposite = category == 'fusion' ? 'diastema' : 'fusion'
    if %w[fusion diastema].include?(category) && patient.odontogram_entries.present_in_mouth.where(tooth: tooth, paired_tooth: paired_tooth, category: opposite).exists?
      errors.add(:base, I18n.t('odontogram.errors.pair_conflict'))
    end
    if patient.odontogram_entries.present_in_mouth.touching_any([tooth, paired_tooth]).where(category: ATTACHMENT_CONFLICTS).exists?
      errors.add(:base, I18n.t('odontogram.errors.pair_support'))
    end
  end

  def validate_position_directions
    allowed = %w[M D V] + ([1, 2, 5, 6].include?(tooth.to_i / 10) ? ['P'] : ['L'])
    valid = position_directions.is_a?(Array) && position_directions.uniq == position_directions &&
      (position_directions - allowed).empty? && (position_directions & %w[M D]).size <= 1 &&
      (position_directions & %w[V P L]).size <= 1 &&
      (category == 'abnormal_position' || position_directions.empty?)
    errors.add(:base, I18n.t('odontogram.errors.position_directions')) unless valid
  end

  def set_rotation_direction
    self.rotation_direction ||= 'unspecified' if category == 'rotation'
  end

  def validate_rotation_direction
    valid = category == 'rotation' ? ROTATION_DIRECTIONS.include?(rotation_direction) : rotation_direction.nil?
    errors.add(:base, I18n.t('odontogram.errors.rotation_direction')) unless valid
  end

  def normalize_mobility_details
    self.mobility_grade = mobility_grade&.strip.presence
    self.mobility_scale = mobility_scale&.strip.presence
  end

  def validate_mobility_details
    return if mobility_grade.blank? && mobility_scale.blank?

    unless category == 'mobility' && mobility_grade.present? && mobility_scale.present? &&
        mobility_grade.length <= 10 && mobility_scale.length <= 60
      errors.add(:base, I18n.t('odontogram.errors.mobility_details'))
    end
  end

  def validate_support
    return unless patient && errors.empty?

    if state == 'removed' || (planned? && treatment_status_in_database == 'completed')
      if %w[missing edentulous_arch].include?(category)
        remaining = patient.odontogram_entries.present_in_mouth.where.not(id: id)
        dentures = remaining.where(category: DENTURE_CATEGORIES).touching_any(target_teeth).to_a
        absence = dentures.empty? ? [] : remaining.where(category: %w[missing edentulous_arch]).to_a
        absent_arches = absence.select { |entry| entry.category == 'edentulous_arch' }.map(&:arch)
        absent_teeth = absence.select { |entry| entry.category == 'missing' }.map(&:tooth)
        blocked = dentures.any? do |denture|
          absent_arch = absent_arches.include?(denture.arch)
          denture.category == 'complete_denture' ? !absent_arch : !absent_arch && (denture.replacement_teeth - absent_teeth).any?
        end
        errors.add(:base, I18n.t('odontogram.editor.arch_has_denture')) if blocked
      end
      if category == 'implant' && implant_markings.present_in_mouth.exists?
        errors.add(:base, I18n.t('odontogram.editor.implant_has_markings'))
      end
      return
    end

    return if planned?

    return if %w[removable_orthodontic edentulous_arch complete_denture partial_denture fixed_bridge].include?(category) && implant_entry_id.blank?

    peers = patient.odontogram_entries.present_in_mouth.touching(tooth).where.not(id: id).where.not(category: %w[removable_orthodontic complete_denture partial_denture fixed_bridge]).to_a
    implant = peers.find { |entry| entry.category == 'implant' }
    if implant_entry_id.present?
      unless IMPLANT_SUPPORTED_CATEGORIES.include?(category) && implant && implant_entry_id == implant.id
        errors.add(:base, I18n.t('odontogram.editor.invalid_implant_support'))
        return
      end
    end

    compatible = case category
    when 'removable_orthodontic', 'edentulous_arch', 'complete_denture', 'partial_denture', 'fixed_bridge'
      true
    when 'implant'
      peers.all? { |entry| %w[missing edentulous_arch].include?(entry.category) || (id.present? && entry.implant_entry_id == id) }
    when 'retained_root'
      peers.none? { |entry| entry.category == 'implant' }
    when 'missing'
      peers.all? { |entry| %w[implant retained_root edentulous_arch].include?(entry.category) || (implant && entry.implant_entry_id == implant.id) }
    else
      peers.none? { |entry| %w[missing implant edentulous_arch].include?(entry.category) } || implant_entry_id.present?
    end
    errors.add(:base, I18n.t('odontogram.editor.structural_conflict')) unless compatible
  end

  def validate_retained_root
    return unless state == 'active' && !planned? && patient

    conflicts = if category == 'retained_root'
      patient.odontogram_entries.present_in_mouth.touching(tooth).where(category: RETAINED_ROOT_CONFLICTS)
    elsif RETAINED_ROOT_CONFLICTS.include?(category)
      patient.odontogram_entries.present_in_mouth.touching(tooth).where(category: 'retained_root')
    end
    if conflicts&.exists?
      errors.add(:base, I18n.t('odontogram.errors.retained_root_conflict'))
    end
  end

  def validate_tooth_size
    return unless state == 'active' && patient && %w[macrodontia microdontia].include?(category)

    opposite = category == 'macrodontia' ? 'microdontia' : 'macrodontia'
    if patient.odontogram_entries.present_in_mouth.where(tooth: tooth, category: opposite).exists?
      errors.add(:base, I18n.t('odontogram.errors.tooth_size_conflict'))
    end
  end

  def validate_vertical_position
    return unless state == 'active' && patient && %w[extrusion intrusion].include?(category)

    opposite = category == 'extrusion' ? 'intrusion' : 'extrusion'
    if patient.odontogram_entries.present_in_mouth.where(tooth: tooth, category: opposite).exists?
      errors.add(:base, I18n.t('odontogram.errors.vertical_position_conflict'))
    end
  end

  def validate_current_marking
    return unless state == 'active' && patient && errors.empty?

    duplicate = marking_peers.where(tooth: tooth, paired_tooth: paired_tooth, category: category).any? do |entry|
      entry.member_teeth == member_teeth && entry.surfaces.sort == surfaces.sort
    end
    errors.add(:base, I18n.t('odontogram.errors.already_recorded')) if duplicate
  end

  def validate_chart_target
    errors.add(:base, I18n.t('odontogram.errors.category')) unless CATEGORIES.include?(category)
    unless TEETH.include?(tooth)
      errors.add(:base, I18n.t('odontogram.errors.tooth'))
      return
    end

    anterior = tooth % 10 <= 3
    upper = [1, 2, 5, 6].include?(tooth / 10)
    allowed = [anterior ? 'F' : 'B', 'M', upper ? 'P' : 'L', 'D', anterior ? 'I' : 'O']
    valid = surfaces.is_a?(Array) && surfaces.uniq == surfaces && (surfaces - allowed).empty?
    unless OPTIONAL_SURFACE_CATEGORIES.include?(category)
      valid &&= SURFACE_CATEGORIES.include?(category) ? surfaces.present? : surfaces.blank?
    end
    errors.add(:base, I18n.t('odontogram.errors.surfaces')) unless valid
  end

  def validate_observation_date
    if observed_on_before_type_cast.present? && (observed_on.nil? || observed_on > Date.current)
      errors.add(:base, I18n.t('odontogram.errors.observed_on'))
    end
  end
end
