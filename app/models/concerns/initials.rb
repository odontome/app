module Initials
  extend ActiveSupport::Concern
  
  def initials
    firstname.chars.first.upcase + lastname.chars.first.upcase
  end
end