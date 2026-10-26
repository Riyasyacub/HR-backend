standard_employee = Role.find_or_create_by!(name: Role::STANDARD_EMPLOYEE)
hr = Role.find_or_create_by!(name: Role::HR)

demo_accounts = {
  "hr@demo.test" => [ "HR Admin", "India", hr ],
  "meera@demo.test" => [ "Meera Nair", "India", standard_employee ],
  "arjun@demo.test" => [ "Arjun Rao", "India", standard_employee ],
  "priya@demo.test" => [ "Priya Sharma", "India", standard_employee ],
  "robert@demo.test" => [ "Robert Miller", "USA", standard_employee ],
  "john@demo.test" => [ "John Davis", "USA", standard_employee ],
  "carol@demo.test" => [ "Carol Smith", "Canada", standard_employee ],
  "emily@demo.test" => [ "Emily Brown", "Canada", standard_employee ]
}

demo_accounts.each do |email, (name, country, role)|
  User.find_or_initialize_by(email:).update!(
    name:, country:, role:, password: "Demo@1234", active: true
  )
end

LeaveType::NAMES.each do |name|
  LeaveType.create_with(default_entitlement: LeaveType::DEFAULT_ENTITLEMENTS[name])
    .find_or_create_by!(name:)
end
