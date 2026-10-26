FactoryBot.define do
  factory :compensation do
    employee
    effective_date { employee.start_date }
    annual_ctc { 1_200_000 }
  end

  factory :compensation_component do
    compensation
    sequence(:name) { |number| "Component #{number}" }
    annual_amount { 1_200_000 }
  end
end
