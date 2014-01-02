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
		assert_equal I18n.t("errors.messages.not_a_number"), appointment.errors[:practice_id].join("; ")
		assert_equal I18n.t("errors.messages.not_a_number"), appointment.errors[:doctor_id].join("; ")
		assert_equal I18n.t("errors.messages.not_a_number"), appointment.errors[:patient_id].join("; ")
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
		UserSession.create users(:founder)
		appointment = Appointment.new(:practice_id => 1,
																	:doctor_id => 1,
																	:patient_id => 1,
																	:starts_at => Time.now)
																	
		assert appointment.save
		assert_equal appointment.ends_at, appointment.starts_at + 60.minutes
	end
	
	test "appointment start date should be before the end date" do
		appointment = Appointment.new(:starts_at => Time.now + 1800,
																	:ends_at => Time.now)
																	
		assert !appointment.save
		assert_equal I18n.t("errors.messages.invalid_date_range"), appointment.errors[:base].join("; ")
	end
	
	test "appointment notes should be within 250 chars" do
		appointment = Appointment.new(:notes => "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor. Quisque condimentum elit aliquam dolor vehicula a suscipit velit dignissim. Nulla laoreet eros eget metus dapibus congue. Mauris vel arcu nec nunc pretium luctus a id justo. Vestibulum mattis commodo hendrerit. Vivamus interdum tempus enim id imperdiet. Integer et tortor ante. Nam sed tortor odio. Sed vulputate, libero quis pulvinar euismod, mauris neque congue diam, vitae aliquam sapien dolor vitae mi. Duis suscipit ligula ut lorem pretium volutpat.")
																	
		assert !appointment.save
		assert_equal I18n.t("errors.messages.too_long", :count => 255), appointment.errors[:notes].join("; ")
		
	end
	
end