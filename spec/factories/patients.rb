FactoryBot.define do
  factory :patient do
    practice # Assumes a practice factory is defined and associated
    firstname { "Patient" }
    lastname { "Zero" }
    # Add any other necessary attributes for a valid patient
  end
end
