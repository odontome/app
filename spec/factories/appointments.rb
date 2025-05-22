FactoryBot.define do
  factory :appointment do
    datebook # Assumes a datebook factory is defined and associated
    doctor # Assumes a doctor factory is defined and associated
    patient # Assumes a patient factory is defined and associated
    starts_at { Time.current }
    # Add any other necessary attributes for a valid appointment
  end
end
