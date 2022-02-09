# frozen_string_literal: true

class Note < ApplicationRecord
  # associations
  belongs_to :noteable, polymorphic: true
  belongs_to :user

  # validations
  validates_presence_of :notes, :user_id
  validates_length_of :notes, in: 3..500
end
