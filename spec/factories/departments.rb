FactoryBot.define do
  factory :department do
    sequence(:name) { |number| "Department #{number}" }
    sequence(:code) { |number| "D#{number}" }
    active { true }
  end
end
