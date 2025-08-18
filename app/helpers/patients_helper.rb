# frozen_string_literal: true

module PatientsHelper
  def letter_options
    alphabet = [*'A'..'Z']
    patients = Patient.with_practice(current_user.practice_id).only_initials.map(&:firstname)

    alphabet.map do |letter|
      {
        value: letter,
        included?: patients.include?(letter)
      }
    end
  end
end
