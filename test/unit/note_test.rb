require 'test_helper'

class NoteTest < ActiveSupport::TestCase

	test "note attributes must not be empty" do
		note = Note.new
		
		assert note.invalid?
		assert note.errors[:user_id].any?
		assert note.errors[:notes].any?
	end

	test "note text should more than 3 chars long" do
		note = Note.new(:notes => "Hi")
																	
		assert !note.save
		assert_equal I18n.t("errors.messages.too_short", :count => 3), note.errors[:notes].join("; ")
		
	end

	test "note text should less than 500 chars long" do
		note = Note.new(:notes => "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vehicula arcu ante, nec eleifend ipsum. Proin vestibulum nisi sit amet diam mattis tempor.")
																	
		assert !note.save
		assert_equal I18n.t("errors.messages.too_long", :count => 500), note.errors[:notes].join("; ")
		
	end

end
