# frozen_string_literal: true

class Announcement < ApplicationRecord
  # associations
  has_many :announcement_dismissals, dependent: :delete_all
  has_many :dismissed_by_users, through: :announcement_dismissals, source: :user

  # validations
  validates_presence_of :version, :announcement_type, :i18n_key
  validates_uniqueness_of :version
  validates_numericality_of :version, only_integer: true, greater_than: 0
  validates_inclusion_of :announcement_type, in: %w[info success warning danger]

  # scopes
  scope :active, -> { where(active: true) }
  scope :published, -> { where('published_at IS NULL OR published_at <= ?', Time.current) }
  scope :current, -> { active.published.order(:version) }

  # Check if this announcement has been dismissed by a specific user
  def dismissed_by?(user)
    return false unless user
    dismissed_by_users.include?(user)
  end

  # Get the translated message for this announcement
  def message
    I18n.t(i18n_key)
  end

  # Get all active announcements that haven't been dismissed by the user
  def self.active_for_user(user = nil)
    announcements = current
    return announcements unless user

    # Filter out announcements dismissed by this user
    dismissed_announcement_ids = user.announcement_dismissals.pluck(:announcement_id)
    announcements.where.not(id: dismissed_announcement_ids)
  end
end
