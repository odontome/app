module PatientsHelper
	def letter_options
	  $letter_options_list ||= ("A".."Z").to_a
	end
end