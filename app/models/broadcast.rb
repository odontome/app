class Broadcast < ApplicationRecord
  # permitted attributes
  attr_accessible :user_id, :subject, :message, :number_of_recipients, :number_of_opens

  scope :with_practice, ->(practice_id) {
    where("users.practice_id = ? ", practice_id)
    .joins(:user)
    .order("created_at")
  }

  # associations
  belongs_to :user

  # validations
  validates_presence_of :subject, :message, :user_id

  # callbacks
end
