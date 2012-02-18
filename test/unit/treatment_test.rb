require 'test_helper'

class TreatmentTest < ActiveSupport::TestCase  
  
  test "treatment attributes must not be empty" do
  	treatment = Treatment.new
  	assert treatment.invalid?
  	assert treatment.errors[:name].any?
  	assert treatment.errors[:price].any?
  end
  	 	
 	test "treatment name must be between 1 and 100 characters" do
 		treatment = Treatment.new
 		treatment.name = "This is a really long treatment name, nothing this large should be able to get inside the database. An error should be displayed to the user to let him or her know about it"
 		treatment.price = 100
 		
 		assert !treatment.save
 		assert_equal I18n.translate("errors.messages.too_long", :count => 100), treatment.errors[:name].join("; ")
 	end
 	
 	test "treatment price must be a valid number" do
 		treatment = Treatment.new
 		treatment.price = "a"
 		
 		assert !treatment.save
 		assert_equal I18n.translate("errors.messages.not_a_number"), treatment.errors[:price].join("; ") 		
 	end
 	
 	test "treatment price must be a positive number" do
 		treatment = Treatment.new
 		treatment.price = -5
 		
 		assert !treatment.save
 		assert_equal I18n.translate("errors.messages.greater_than", :count => 0), treatment.errors[:price].join("; ")
 	end
 
 end
