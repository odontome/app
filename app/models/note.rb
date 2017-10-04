class Note < ApplicationRecord
  # permitted attributes
  attr_accessible :notes

  # associations
  belongs_to :noteable, :polymorphic => true
  belongs_to :user
  
  # validations  
  validates_presence_of :notes, :user_id
  validates_length_of :notes, :in => 3..500

  # callbacks
  before_validation :set_user

  private 

  def set_user
  	if UserSession.find
    	self.user_id = UserSession.find.user.id
    end
  end
  
end
