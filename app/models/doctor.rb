class Doctor < ActiveRecord::Base
  belongs_to :practice
  has_many :appointments
  has_many :patients, :through => :appointments

  scope :mine, lambda { 
    where("doctors.practice_id = ? ", UserSession.find.user.practice_id)
  }  
  
  validates_presence_of :practice_id, :firstname, :lastname
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_length_of :uid, :within => 0..25, :allow_blank => true
  validates_length_of :speciality, :within => 0..50, :allow_blank => true
  validates_format_of :email, :with => Authlogic::Regex.email, :allow_blank => true

  before_validation(:on => :create) do
    set_practice_id
  end
  
  before_destroy :check_if_is_deleteable
  
  def fullname
    [(self.gender === "female") ? s_('female_doctor_prefix|Dr.') : s_('male_doctor_prefix|Dr.'), firstname, lastname].join(' ')
  end
  
  def is_deleteable
    return false if self.appointments.count > 0
  end


  private
  
  def check_if_is_deleteable
    if self.is_deleteable
      self.errors[:base] << _("Can't delete Doctor with registered appointmens")
      false
    end
    
  end
  
end
