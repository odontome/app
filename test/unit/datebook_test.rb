require 'test_helper'

class DatebookTest < ActiveSupport::TestCase

	test "datebook attributes must not be empty" do
		datebook = Datebook.new
		
		assert datebook.invalid?
		assert datebook.errors[:practice_id].any?
		assert datebook.errors[:name].any?
	end

	test "datebook practice_id should be set from the session" do
		UserSession.create users(:founder)
		datebook = Datebook.new(:name => "Consulta #1")
																	
		assert datebook.save
		assert_equal datebook.practice_id, users(:founder).practice_id
	end
end
