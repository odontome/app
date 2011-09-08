module PatientsHelper
	def letter_options
	  letter_options_list = Patient.mine.collect!{ |c| c.firstname.first.upcase }.uniq.sort!
	 	#letter_options_list ||= ("A".."Z").to_a
	end
end