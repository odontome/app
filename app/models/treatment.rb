# frozen_string_literal: true

class Treatment < ApplicationRecord
  # PaperTrail for audit logging
  has_paper_trail meta: { practice_id: :practice_id }

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

  # validations
  validates_presence_of :practice_id, :name, :price
  validates_length_of :name, within: 1..100
  validates_numericality_of :price

  # callbacks

  def missing_info?
    price.nil? || price <= 0
  end
end
