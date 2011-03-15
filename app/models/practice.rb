class Practice < ActiveRecord::Base

  # Practice status:
  # free - default when account is created or downgraded from paid plan
  # active - when subscription payment is active. Set by paypal on plan signup and every month when card is charged
  # payment_due - set by paypal when the card couldn't be charged. Paypal tries 3 times before sending "cancelled"
  # expiring - set when user or us cancel the subscription on paypal. Account will be here until the month expires
  # cancelled - account terminated. User or admin wants to close it or payment in paypal have had stopped. Will be here for 30 days, then it should be deleted from DB.

  has_many :users, :dependent => :destroy 
  has_many :doctors, :dependent => :destroy 
  belongs_to :plan
  accepts_nested_attributes_for :users, :limit => 1
  validates_presence_of :plan_id

  def cancel!
    self.status = "cancelled"
    self.cancelled_at = Time.now
  end

end
