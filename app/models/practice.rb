class Practice < ActiveRecord::Base
  has_many :users, :dependent => :destroy 
  has_many :doctors, :dependent => :destroy 
  accepts_nested_attributes_for :users, :limit => 1
end
