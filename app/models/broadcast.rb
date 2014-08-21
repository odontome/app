class Broadcast < ActiveRecord::Base
  # permitted attributes
  attr_accessible :user_id, :subject, :message, :number_of_recipients, :number_of_opens

  scope :mine, lambda {
    where("users.practice_id = ? ", UserSession.find.user.practice_id)
    .joins(:users)
    .order("created_at")
  }

  # associations
  belongs_to :user

  # validations
  validates_presence_of :subject, :message
end
