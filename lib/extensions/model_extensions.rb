class ActiveRecord::Base

   def set_practice_id
     if UserSession.find
       self.practice_id = UserSession.find.user.practice_id
     end
   end
   
end

# extending the functionality of the "Audit" gem
class Audit
	before_create :set_practice_id
	before_save :set_username

  scope :mine, lambda { 
     where("audits.practice_id = ? ", UserSession.find.user.practice_id)
  }
  scope :recent, lambda {
  	mine
    .where('created_at > ?', 7.days.ago)
    .order('created_at desc')
    .limit(25)
  }
  
  def set_username
  	self.username = UserSession.find.user.fullname
  end
end