# frozen_string_literal: true

class Treatment < ApplicationRecord
  # PaperTrail for audit logging
  has_paper_trail meta: { practice_id: ->(treatment) { treatment.practice_id } }

  # associations
  belongs_to :practice

  scope :with_practice, lambda { |practice_id|
    where('treatments.practice_id = ? ', practice_id)
      .order('name')
  }

  scope :for_odontogram, -> { where(builtin_category: nil, odontogram_category: OdontogramEntry::CATEGORIES).order(:name, :id) }

  # validations
  validates_presence_of :practice_id, :name
  validates_length_of :name, within: 1..100
  validates_numericality_of :price, allow_nil: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 9_999_999_999.99
  validates :builtin_category, inclusion: { in: OdontogramEntry::TREATMENT_CATEGORIES }, allow_nil: true
  validates :builtin_category, uniqueness: { scope: :practice_id }, if: :builtin?
  validates :odontogram_category, inclusion: { in: OdontogramEntry::CATEGORIES,
    message: ->(*) { I18n.t('odontogram.errors.category') } }, allow_nil: true

  # callbacks
  before_validation :normalize_odontogram_category
  before_validation :set_builtin_definition
  before_destroy :preserve_builtin

  # Definitions are shared; only a practice's price override needs a database row.
  def self.catalogue_for(practice)
    records = practice.treatments.to_a
    custom = records.reject(&:builtin?)
    overrides = records.select(&:builtin?).index_by(&:builtin_category)
    custom += OdontogramEntry::TREATMENT_CATEGORIES.map do |category|
      overrides[category] || new(practice_id: practice.id, builtin_category: category, name: category, odontogram_category: category)
    end
    custom.sort_by { |treatment| I18n.transliterate(treatment.display_name).downcase }
  end

  def builtin?
    builtin_category.present?
  end

  def display_name
    builtin? ? I18n.t("odontogram.categories.#{builtin_category}") : name
  end

  def to_param
    builtin? ? "builtin-#{builtin_category}" : super
  end

  def odontogram_preset
    { id: id, name: name, category: odontogram_category, version: updated_at.utc.iso8601(6) }
  end

  private

  def set_builtin_definition
    return unless builtin?

    self.name = builtin_category
    self.odontogram_category = builtin_category
  end

  def preserve_builtin
    throw :abort if builtin?
  end

  def normalize_odontogram_category
    self.odontogram_category = nil if odontogram_category.blank?
  end
end
