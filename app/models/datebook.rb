# frozen_string_literal: true

class Datebook < ApplicationRecord
  # PaperTrail for audit logging
  has_paper_trail meta: { practice_id: ->(datebook) { datebook.practice_id } }

  # associations
  has_many :appointments
  belongs_to :practice, counter_cache: true

  scope :with_practice, lambda { |practice_id|
    where('datebooks.practice_id = ? ', practice_id)
  }

  # validations
  validates_presence_of :practice_id, :name
  validates_numericality_of :practice_id
  validates :name, length: { within: 0..100 }
  validates_numericality_of :starts_at, greater_than: 0
  validates_numericality_of :starts_at, less_than_or_equal_to: 22
  validates_numericality_of :ends_at, greater_than: :starts_at
  validates_numericality_of :ends_at, less_than_or_equal_to: 23

  # callbacks
  before_destroy :check_if_is_deleteable

  def is_deleteable
    appointments.count.zero?
  end

  def working_hours
    { start: format('%02d:00', starts_at), end: format('%02d:00', ends_at) }
  end

  def within_working_hours?(starts_at, ends_at)
    return false unless starts_at && ends_at && starts_at < ends_at

    local_start = starts_at.in_time_zone(practice.timezone)
    opens = local_start.change(hour: self.starts_at)
    closes = local_start.change(hour: self.ends_at)
    starts_at >= opens && ends_at <= closes
  end

  private

  def check_if_is_deleteable
    return if is_deleteable

    errors.add(:base, I18n.t('errors.messages.has_appointments'))
    throw :abort
  end
end
