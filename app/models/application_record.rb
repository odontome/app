class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def set_practice_id
    if UserSession.find
      self.practice_id = UserSession.find.user.practice_id
    end
  end
  
end