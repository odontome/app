# frozen_string_literal: true

module PatientsHelper
  def letter_options
    alphabet = [*'A'..'Z']
    patients = Patient.with_practice(current_user.practice_id).valid.only_initials.map(&:firstname)
    
    alphabet.map do |letter|
      {
        value: letter,
        included?: patients.include?(letter)
      }  
    end
  end

  def link_to_suspend_or_delete(patient, options)
    if (patient.is_deleteable || patient.is_active) && options.dig(:class)&.exclude?("btn")
      options.dig(:class).concat(' text-red')
    end

    if patient.is_deleteable
      link_to t(:delete), patient, :method => :delete, **options, data: { confirm: t(:are_you_sure) }
    else
      link_to patient.is_active ? t(:suspend) : t(:activate), patient, **options, :method => :delete,
                                                                       data: { confirm: t(:are_you_sure) }
    end
  end

  def status_tag(patient)
    if patient.is_active
      label_tag t(:active), :green
    else
      label_tag t(:suspended), :red
    end
  end
end
