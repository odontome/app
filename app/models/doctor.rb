class Doctor < ActiveRecord::Base
  belongs_to :practice
  #has_many :appointments, :dependent => :destroy 

  scope :mine, lambda { 
    where("doctors.doctor_id = ? ", UserSession.find.user.practice_id)
  }  
  
  validates_presence_of :practice_id, :firstname, :lastname
  validates :uid, :uniqueness => {:scope => :practice_id}
  validates_length_of :speciality, :within => 0..50

  before_validation(:on => :create) do
    set_practice_id
  end
  
  def fullname
    [(self.gender === "female") ? "Dr." : "Dr.", firstname, lastname].join(' ')
  end
  
end
