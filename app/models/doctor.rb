class Doctor < ActiveRecord::Base
  belongs_to :practice
  #has_many :appointments

  scope :mine, lambda { 
    where("doctors.practice_id = ? ", UserSession.find.user.practice_id)
  }  
  
  validates_presence_of :practice_id, :firstname, :lastname
  validates :uid, :uniqueness => {:scope => :practice_id}
  validates_length_of :speciality, :within => 0..50, :allow_blank => true
  validates_format_of :email, :with => Authlogic::Regex.email

  before_validation(:on => :create) do
    set_practice_id
  end
  
  before_destroy :check_if_is_deleteable
  
  def fullname
    [(self.gender === "female") ? "Dr." : "Dr.", firstname, lastname].join(' ')
  end
  
  def is_deleteable
    return false if self.appointments.count > 0
  end


  private
  
  def check_if_is_deleteable
    if self.is_deleteable
      self.errors[:base] << "Can't delete Doctor with registered appointmens"
      false
    end
    
  end
  
end
