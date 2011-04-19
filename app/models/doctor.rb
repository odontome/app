class Doctor < ActiveRecord::Base
  belongs_to :practice
  has_many :appointments
  has_many :patients, :through => :appointments
  has_many :patient_treatments

  scope :mine, lambda { 
    where("doctors.practice_id = ? ", UserSession.find.user.practice_id)
  }  
  
  # validations
  validates_presence_of :practice_id, :firstname, :lastname
  validates_uniqueness_of :uid, :scope => :practice_id, :allow_nil => true, :allow_blank => true
  validates_length_of :uid, :within => 0..25, :allow_blank => true
  validates_length_of :speciality, :within => 0..50, :allow_blank => true
  validates_format_of :email, :with => Authlogic::Regex.email, :allow_blank => true
  
  # callbacks
  before_validation :set_practice_id, :on => :create
  before_destroy :check_if_is_deleteable
  
  # constants
  COLORS = [[_('Blue'), "#3366CC"],    
            [_('Orange'), "#FF8600" ],
            [_('Purple'), "#622EB4"],
            [_('Red'), "#FD0000"],
            [_('Black'), "#000000"],
            [_('Green'), "#00B600"],
            [_('Pink'), "#FF66CC"]]
  
  def fullname
    [(self.gender === "female") ? s_('female_doctor_prefix|Dr.') : s_('male_doctor_prefix|Dr.'), firstname, lastname].join(' ')
  end
  
  def is_deleteable
    return true if self.appointments.count == 0 && self.patient_treatments.count == 0
  end

  private
  
  def check_if_is_deleteable
    unless self.is_deleteable
      self.errors[:base] << _("Can't delete a doctor with registered appointments or patient's treatments, please use 'Suspend' instead.")
      false
    end
    
  end
  
end
