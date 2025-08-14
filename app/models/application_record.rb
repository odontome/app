# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Configure PaperTrail to track user information
  def paper_trail_originator
    return nil unless defined?(PaperTrail) && PaperTrail.request.enabled?
    
    if PaperTrail.request.whodunnit.present?
      user = User.find_by(id: PaperTrail.request.whodunnit)
      user&.fullname || PaperTrail.request.whodunnit
    end
  end
end
