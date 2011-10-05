require 'test_helper'

class PatientTest < ActiveSupport::TestCase
		
	test "patient attributes must not be empty" do
		patient = Patient.create
				
		assert patient.invalid?		
		assert patient.errors[:practice_id].any?
		assert patient.errors[:firstname].any?
		assert patient.errors[:lastname].any?
		assert patient.errors[:date_of_birth].any?
		assert patient.errors[:past_illnesses].any?
		assert patient.errors[:surgeries].any?
		assert patient.errors[:medications].any?
		assert patient.errors[:drugs_use].any?
		assert patient.errors[:family_diseases].any?
		assert patient.errors[:emergency_telephone].any?
		assert patient.errors[:cigarettes_per_day].any?
		assert patient.errors[:drinks_per_day].any?
	end
	
	test "patient is not valid without an unique uid" do	
		patient = Patient.new(:uid => 0001,
										:practice_id => 1,
										:firstname => "Daniella",
										:lastname => "Sanguino")
													
		assert !patient.save
		assert_equal I18n.translate("activerecord.errors.messages.taken"), patient.errors[:uid].join("; ")
	end
	
	test "patient vices must be numbers" do
		patient = patients(:two)
		
		patient.cigarettes_per_day = "none"
		patient.drinks_per_day = "not a sip"
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.not_a_number"), patient.errors[:cigarettes_per_day].join("; ")
		assert_equal I18n.translate("errors.messages.not_a_number"), patient.errors[:drinks_per_day].join("; ")
	end
	
	test "patient vices must be valid integers" do
		patient = patients(:two)
		
		patient.cigarettes_per_day = 0.5
		patient.drinks_per_day = 0.75
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.not_an_integer"), patient.errors[:cigarettes_per_day].join("; ")
		assert_equal I18n.translate("errors.messages.not_an_integer"), patient.errors[:drinks_per_day].join("; ")
	end
	
	test "patient vices must be greater than or equal to zero" do
		patient = patients(:two)
		
		patient.cigarettes_per_day = -5
		patient.drinks_per_day = -2
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.greater_than_or_equal_to", :count => 0), patient.errors[:cigarettes_per_day].join("; ")
		assert_equal I18n.translate("errors.messages.greater_than_or_equal_to", :count => 0), patient.errors[:drinks_per_day].join("; ")
	end

	test "patient uid must be between 0 and 25 characters" do
		patient = patients(:one)
		patient.uid = "00001111222233334444555666677778888"
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_long", :count => 25), patient.errors[:uid].join("; ")
	end
	
	test "patient name must be between 1 and 25 characters" do
		patient = patients(:one)
		patient.firstname = "A really long name that nobody will really use"
		patient.lastname = "A really long last name as well really weird"
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_long", :count => 25), patient.errors[:firstname].join("; ")
		assert_equal I18n.translate("errors.messages.too_long", :count => 25), patient.errors[:lastname].join("; ")
	end
	
	test "patient address must be between 0 and 100 characters" do
		patient = patients(:one)
		patient.address = "A really long address, maybe this guy lives somewhere in Venezuela where the addresses are just insanely huge!"
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_long", :count => 100), patient.errors[:address].join("; ")
	end
	
	test "patient phone numbers must be between 0 and 20 characters" do
		patient = patients(:one)
		patient.telephone = "+3491456789876456667890"
		patient.mobile = "+346645678987645643689032"
		
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_long", :count => 20), patient.errors[:telephone].join("; ")
		assert_equal I18n.translate("errors.messages.too_long", :count => 20), patient.errors[:mobile].join("; ")
	end
	
	test "patient emergency telephone must be at least 5 characters long" do
		patient = patients(:one)
		patient.emergency_telephone = "0000"
				
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_short", :count => 5), patient.errors[:emergency_telephone].join("; ")
	end
	
	test "patient emergency telephone must be a maximum of 20 chars long" do
		patient = patients(:one)
		patient.emergency_telephone = "+346645678987645643689032"
				
		assert !patient.save
		assert_equal I18n.translate("errors.messages.too_long", :count => 20), patient.errors[:emergency_telephone].join("; ")
	end
	
	test "patient is not valid without a valid email address" do
		patient = patients(:one)
		patient.email = "notvalid@"
													
		assert !patient.save
		assert_equal I18n.translate("errors.messages.invalid"), patient.errors[:email].join("; ")
	end
	
	test "patient fullname shortcut" do
		patient = patients(:one)
		another_patient = Patient.new(:fullname => "Daniella Sanguino")
		
		assert_equal patient.fullname, "#{patient.firstname} #{patient.lastname}"
		assert_equal "#{another_patient.firstname} #{another_patient.lastname}", another_patient.fullname
	end
	
	test "patient age" do
		patient = patients(:one)
		
		assert patient.age.integer?
		assert patient.age > 0
	end
	
	test "patient is invalid if it has no date of birth" do
		patient = patients(:one)
		patient.date_of_birth = nil
		
		assert patient.invalid?
	end
	
	test "patient can not be created if the limit has been reached in beta" do
		$beta_mode = true
		UserSession.create users(:user_in_yet_another_practice)
		patient = Patient.new(
										:practice_id => 3,
										:firstname => "Daniella",
										:lastname => "Sanguino",
										:date_of_birth => "1988-11-16",
										:past_illnesses => "none",
										:surgeries => "none",
										:medications => "none",
										:drugs_use => "none",
										:cigarettes_per_day => 0,
										:drinks_per_day => 0,
										:family_diseases => "none",
										:emergency_telephone => "call my mom"
									)
		
		assert !patient.save
		assert_equal "We are very sorry, but you have reached the patients limit for this private beta. Please contact us if you need assistance.", patient.errors[:base].join("; ")
	end
	
	test "patient can not be created if the limit has been reached" do
		$beta_mode = false
		UserSession.create users(:user_in_yet_another_practice)
		patient = Patient.new(
										:practice_id => 3,
										:firstname => "Daniella",
										:lastname => "Sanguino",
										:date_of_birth => "1988-11-16",
										:past_illnesses => "none",
										:surgeries => "none",
										:medications => "none",
										:drugs_use => "none",
										:cigarettes_per_day => 0,
										:drinks_per_day => 0,
										:family_diseases => "none",
										:emergency_telephone => "call my mom"
									)

		assert !patient.save
		assert_equal "We are very sorry, but you have reached your patients limit. Please upgrade your account in My Practice settings", patient.errors[:base].join("; ")
	end

end