FactoryBot.define do
  factory :user do
    practice # Assumes a practice factory is defined and associated
    email { "user@example.com" } # Add other necessary attributes
    password { "password" }
    # Add any other necessary attributes for a valid user
  end
end
