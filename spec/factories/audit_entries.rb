FactoryBot.define do
  factory :audit_entry do
    association :actor, factory: :user
    association :auditable, factory: :leave_type
    action { "update" }
    change_set { {} }
  end
end
