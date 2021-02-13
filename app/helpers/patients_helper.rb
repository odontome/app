module PatientsHelper
  def letter_options
    letter_options_list = Patient.with_practice(current_user.practice_id).to_a.collect! do |c|
      c.firstname.first.upcase
    end.uniq.sort!
    # letter_options_list ||= ("A".."Z").to_a
  end
end
