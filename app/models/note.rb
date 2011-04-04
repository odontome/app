class Note < ActiveRecord::Base
  belongs_to :noteable, :polymorphic => true
    
  validates_presence_of :notes
  validates_length_of :notes, :in => 3..500
end
