class Note < ActiveRecord::Base
  # permitted attributes
  attr_accessible :notes

  # associations
  belongs_to :noteable, :polymorphic => true
  
  # validations  
  validates_presence_of :notes
  validates_length_of :notes, :in => 3..500
  
end
