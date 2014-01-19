require 'test_helper'

class DatebookTest < ActiveSupport::TestCase

	test "datebook attributes must not be empty" do
		datebook = Datebook.new
		
		assert datebook.invalid?
		assert datebook.errors[:practice_id].any?
		assert datebook.errors[:name].any?
	end

	test "datebook name should be less than 100 chars" do
		datebook = Datebook.new(:name => "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor.")
																	
		assert !datebook.save
		assert_equal I18n.t("errors.messages.too_long", :count => 100), datebook.errors[:name].join("; ")
		
	end

	test "datebook practice_id should be set from the session" do
		UserSession.create users(:founder)
		datebook = Datebook.new(:name => "Consulta #1")
																	
		assert datebook.save
		assert_equal datebook.practice_id, users(:founder).practice_id
	end
end
