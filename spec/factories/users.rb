FactoryBot.define do
  factory :user do
    role { Role.find_or_create_by!(name: Role::STANDARD_EMPLOYEE) }
    sequence(:name) { |number| "Employee #{number}" }
    sequence(:email) { |number| "employee#{number}@demo.test" }
    password { "Demo@1234" }
    country { "India" }
    status { "active" }
    active { true }

    trait :hr do
      role { Role.find_or_create_by!(name: Role::HR) }
    end
  end
end
