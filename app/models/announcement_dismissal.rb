# frozen_string_literal: true

class AnnouncementDismissal < ApplicationRecord
  # associations
  belongs_to :user
  belongs_to :announcement

  # validations
  validates_presence_of :user_id, :announcement_id
  validates_uniqueness_of :announcement_id, scope: :user_id
end
