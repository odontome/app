class Practice < ActiveRecord::Base

  # Practice status:
  # cancelled - account terminated. User or admin wants to close it. Will be here for 30 days, then it should be deleted from DB.
  
  # associations
  has_many :users, :dependent => :delete_all    # didn't work with :destroy 'cause if the before_destroy callback in User.rb 
  has_many :appointments, :dependent => :delete_all
  has_many :doctors, :dependent => :delete_all 
  has_many :patients, :dependent => :destroy # uses :destroy so User.rb deletes_all its children
  has_many :treatments, :dependent => :delete_all 

  accepts_nested_attributes_for :users, :limit => 1
  
  # validations
  validates_presence_of :name

  # callbacks
  before_validation :set_first_user_data, :on => :create

  def set_as_cancelled
    self.status = "cancelled"
    self.cancelled_at = Time.now
  end

  def populate_default_treatments
    TREATMENTS[self.locale || 'en']['treatments'].each do |treatment|
      self.treatments << Treatment.new(:name => treatment, :price => 0)
    end
  end  

  private
  
  def set_first_user_data
    self.users.first.firstname = I18n.t :administrator
    self.users.first.lastname = (I18n.t :user).downcase
  end

end
