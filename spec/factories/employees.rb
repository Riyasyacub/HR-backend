FactoryBot.define do
  factory :employee do
    department
    sequence(:employee_id) { |number| "EMP#{100 + number}" }
    first_name { "Ravi" }
    last_name { "Kumar" }
    sequence(:work_email) { |number| "employee#{number}@demo.test" }
    country { "India" }
    job_title { "Software Engineer" }
    start_date { Date.current }
    bank_name { "HDFC Bank" }
    ifsc { "HDFC0001234" }
    account_number { "123456789012" }
    status { "active" }
  end
end
