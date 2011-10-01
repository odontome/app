require 'test_helper'

class AppointmentTest < ActiveSupport::TestCase

	test "appointment attributes must not be empty" do
		appointment = Appointment.new
		
		assert appointment.invalid?
		assert appointment.errors[:practice_id].any?
		assert appointment.errors[:doctor_id].any?
		assert appointment.errors[:patient_id].any?
	end
	
	test "appointment references must be numbers" do
		appointment = appointments(:first_visit)
		
		appointment.practice_id = "not valid"
		appointment.doctor_id = "not a number"
		appointment.patient_id = "not even close"
		
		assert !appointment.save
		assert_equal I18n.translate("errors.messages.not_a_number"), appointment.errors[:practice_id].join("; ")
		assert_equal I18n.translate("errors.messages.not_a_number"), appointment.errors[:doctor_id].join("; ")
		assert_equal I18n.translate("errors.messages.not_a_number"), appointment.errors[:patient_id].join("; ")
	end
	
	test "appointment practice_id should be set from the session" do
		UserSession.create users(:founder)
		appointment = Appointment.new(:doctor_id => 1,
																	:patient_id => 1,
																	:starts_at => Time.now)
																	
		assert appointment.save
		assert_equal appointment.practice_id, users(:founder).practice_id
	end
	
	test "appointment end date should be 60mins by default" do
		appointment = Appointment.new(:practice_id => 1,
																	:doctor_id => 1,
																	:patient_id => 1,
																	:starts_at => Time.now)
																	
		assert appointment.save
		assert_equal appointment.ends_at, appointment.starts_at + 60.minutes
	end
	
	test "appointment start date should be before the end date" do
		appointment = Appointment.new(:practice_id => 1,
																	:doctor_id => 1,
																	:patient_id => 1,
																	:starts_at => Time.now + 1800,
																	:ends_at => Time.now)
																	
		assert !appointment.save
		assert_equal _("Invalid date range"), appointment.errors[:base].join("; ")
	end
	
end