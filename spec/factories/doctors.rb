FactoryBot.define do
  factory :doctor do
    practice # Assumes a practice factory is defined and associated
    firstname { "Doctor" }
    lastname { "Strange" }
    # Add any other necessary attributes for a valid doctor
  end
end
