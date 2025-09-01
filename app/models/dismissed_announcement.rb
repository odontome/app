# frozen_string_literal: true

class DismissedAnnouncement < ApplicationRecord
  # associations
  belongs_to :user

  # validations
  validates_presence_of :user_id, :announcement_version
  validates_uniqueness_of :announcement_version, scope: :user_id
  validates_numericality_of :announcement_version, only_integer: true, greater_than: 0

  # scopes
  scope :for_user, lambda { |user_id|
    where(user_id: user_id)
  }

  scope :for_versions, lambda { |versions|
    where(announcement_version: versions)
  }
end