class Practice < ActiveRecord::Base

  # Practice status:
  # free - default when account is created or downgraded from paid plan
  # active - when subscription payment is active. Set by paypal on plan signup and every month when card is charged
  # payment_due - set by paypal when the card couldn't be charged. Paypal tries 3 times before sending "cancelled"
  # expiring - set when user or us cancel the subscription on paypal. Account will be here until the month expires
  # cancelled - account terminated. User or admin wants to close it or payment in paypal have had stopped. Will be here for 30 days, then it should be deleted from DB.
  
  # associations
  has_many :users, :dependent => :destroy 
  has_many :doctors, :dependent => :destroy 
  has_many :patients, :dependent => :destroy 
  has_many :treatments, :dependent => :destroy 
  belongs_to :plan
  accepts_nested_attributes_for :users, :limit => 1
  
  # validations
  validates_presence_of :plan_id, :name
  validates_presence_of :invitation_code, :if => :beta_mode_on?
  validate :correctness_of_invitation_code, :on => :create

  #callbacks
  before_validation :set_first_user_data, :on => :create

  def set_as_cancelled
    self.status = "cancelled"
    self.cancelled_at = Time.now
  end
  
  def set_plan_id_and_number_of_patients=(plan_id)
    PLANS.each do |plan, values|
      if values['id'].to_i == plan_id.to_i
          # if we manually set an account to have say 10.000 patients don't touch it no matter what plan is beign paid
          if self.number_of_patients < values['number_of_patients'].to_i
            self.number_of_patients = values['number_of_patients'].to_i
          end
          if plan_id.to_i > 1
            self.status = "active"
          else
            self.status = "free"
            self.number_of_patients = values['number_of_patients'].to_i
          end
          self.plan_id = plan_id
          break
      end
    end
  end

  private
  
  def set_first_user_data
    self.users.first.firstname = 'Administrator'
    self.users.first.lastname = 'User'
  end

  def beta_mode_on?
    #validations pass when false (or something)
    false if $beta_mode
  end

  def correctness_of_invitation_code
    tester = Prefinery::Tester.new(:beta_id => 1529)
    tester.email = self.users.first.email
    tester.status = 'active'
    tester.invitation_code = self.invitation_code
    errors.add(:invitation_code, _("seems to be invalid or its maximum allowed testers has been reached. Please check it or go to http://odonto.me to request access to this private beta.")) unless tester.save
  end

end
