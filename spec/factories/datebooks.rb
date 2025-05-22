FactoryBot.define do
  factory :datebook do
    practice # Assumes a practice factory is defined and associated
    name { "MyString" }
    # Add any other necessary attributes for a valid datebook
  end
end
