class Practice < ActiveRecord::Base
  has_many :users, :dependent => :destroy 
  has_many :doctors, :dependent => :destroy 
  belongs_to :plan
  accepts_nested_attributes_for :users, :limit => 1
  validates_presence_of :plan_id
end
