class Practice < ActiveRecord::Base
  # permitted attributes
  attr_accessible :name, :users_attributes, :locale, :timezone, :currency_unit
  
  # associations
  has_many :users, :dependent => :delete_all    # didn't work with :destroy 'cause if the before_destroy callback in User.rb 
  has_many :datebooks, :dependent => :delete_all
  has_many :doctors, :dependent => :delete_all 
  has_many :patients, :dependent => :destroy # uses :destroy so User.rb deletes_all its children
  has_many :treatments, :dependent => :delete_all 

  accepts_nested_attributes_for :users, :limit => 1
  
  # validations
  validates_presence_of :name, :timezone, :locale

  # callbacks
  before_validation :set_timezone_and_locale, :on => :create
  before_validation :set_first_user_data, :on => :create
  after_create :create_first_datebook

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
  
  def set_timezone_and_locale
    self.timezone = Time.zone.name
    self.locale = "en"
  end

  def set_first_user_data
    self.users.first.firstname = I18n.t :administrator
    self.users.first.lastname = (I18n.t :user).downcase
  end

  def create_first_datebook
    Datebook.create({ :practice_id => self.id, :name => I18n.t(:your_first_datebook) })
  end

end
