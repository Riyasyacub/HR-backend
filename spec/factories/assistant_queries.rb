FactoryBot.define do
  factory :assistant_query do
    user
    question { "headcount by country" }
    status { "answered" }
  end
end
