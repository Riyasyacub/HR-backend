FactoryBot.define do
  factory :leave_type do
    name { "Earned" }
    default_entitlement { 12 }

    trait :unpaid do
      name { "Unpaid" }
      default_entitlement { nil }
    end
  end
end
