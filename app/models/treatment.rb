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

  scope :valid, lambda {
    where('price IS NOT NULL')
      .where('price != 0')
  }

  scope :for_odontogram, -> { where(odontogram_category: OdontogramEntry::CATEGORIES).order(:name, :id) }

  # validations
  validates_presence_of :practice_id, :name, :price
  validates_length_of :name, within: 1..100
  validates_numericality_of :price
  validates :odontogram_category, inclusion: { in: OdontogramEntry::CATEGORIES,
    message: ->(*) { I18n.t('odontogram.errors.category') } }, allow_nil: true

  # callbacks
  before_validation :normalize_odontogram_category

  def odontogram_preset
    { id: id, name: name, category: odontogram_category, version: updated_at.utc.iso8601(6) }
  end

  def missing_info?
    price.nil? || price <= 0
  end

  private

  def normalize_odontogram_category
    self.odontogram_category = nil if odontogram_category.blank?
  end
end
