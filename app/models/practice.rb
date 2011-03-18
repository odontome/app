class Practice < ActiveRecord::Base

  # Practice status:
  # free - default when account is created or downgraded from paid plan
  # active - when subscription payment is active. Set by paypal on plan signup and every month when card is charged
  # payment_due - set by paypal when the card couldn't be charged. Paypal tries 3 times before sending "cancelled"
  # expiring - set when user or us cancel the subscription on paypal. Account will be here until the month expires
  # cancelled - account terminated. User or admin wants to close it or payment in paypal have had stopped. Will be here for 30 days, then it should be deleted from DB.

  has_many :users, :dependent => :destroy 
  has_many :doctors, :dependent => :destroy 
  has_many :patients, :dependent => :destroy 
  belongs_to :plan
  accepts_nested_attributes_for :users, :limit => 1
  validates_presence_of :plan_id

  before_create do
    set_number_of_patients(1)
  end

  def cancel!
    self.status = "cancelled"
    self.cancelled_at = Time.now
  end
  
  def set_number_of_patients(plan_id)
    PLANS.each do |plan, values|
      if values['id'].to_i == plan_id
          puts "=================="
          puts self.number_of_patients
          puts values['number_of_patients']
          puts "=================="
          # if we manually set an account to have say 10.000 patients don't touch it no matter what plan is beign paid
          if self.number_of_patients && self.number_of_patients < values['number_of_patients'].to_i
            self.number_of_patients = values['number_of_patients'].to_i
          elsif self.number_of_patients.nil?
            self.number_of_patients = values['number_of_patients'].to_i
          end
          break
      end
    end
  end
  
end
