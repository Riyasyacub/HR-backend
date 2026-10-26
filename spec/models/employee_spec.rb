require "rails_helper"

RSpec.describe Employee, type: :model do
  subject(:employee) { build(:employee) }

  it { is_expected.to be_valid }

  describe "currency" do
    it "derives the currency from the country" do
      expect(build(:employee, country: "India").tap(&:validate).currency).to eq("INR")
      expect(build(:employee, country: "Canada").tap(&:validate).currency).to eq("CAD")
    end

    it "updates the currency when the country changes" do
      employee.save!

      employee.update!(country: "USA")

      expect(employee.currency).to eq("USD")
    end
  end

  it "requires the employee record fields" do
    employee.assign_attributes(
      employee_id: nil, first_name: nil, last_name: nil, work_email: nil,
      job_title: nil, start_date: nil, department: nil,
      bank_name: nil, account_number: nil, status: nil
    )

    expect(employee).not_to be_valid
    expect(employee.errors.attribute_names).to include(
      :employee_id, :first_name, :last_name, :work_email, :job_title,
      :start_date, :department, :bank_name, :account_number, :status
    )
  end

  it "rejects invalid work email formats" do
    expect(build(:employee, work_email: "not-an-email")).not_to be_valid
  end

  it "rejects duplicate employee IDs and work emails case-insensitively" do
    create(:employee, employee_id: "EMP101", work_email: "ravi@demo.test")
    duplicate = build(:employee, employee_id: "emp101", work_email: "RAVI@demo.test")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:employee_id]).to be_present
    expect(duplicate.errors[:work_email]).to be_present
  end

  it "enforces unique employee IDs in the database" do
    create(:employee, employee_id: "EMP101")
    duplicate = build(:employee, employee_id: "emp101", currency: "INR")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "enforces unique work emails in the database" do
    create(:employee, work_email: "ravi@demo.test")
    duplicate = build(:employee, work_email: "RAVI@demo.test", currency: "INR")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "keeps employee ID and work email immutable" do
    employee.save!
    employee.employee_id = "EMP999"
    employee.work_email = "changed@demo.test"

    expect(employee).not_to be_valid
    expect(employee.errors[:employee_id]).to be_present
    expect(employee.errors[:work_email]).to be_present
  end

  it "accepts only onboarding or active status" do
    expect(build(:employee, status: "onboarding")).to be_valid
    expect(build(:employee, status: "active")).to be_valid
    expect(build(:employee, status: "notice")).not_to be_valid
  end

  it "allows only one employee per user" do
    user = create(:user)
    create(:employee, user:)

    expect(build(:employee, user:)).not_to be_valid
  end

  it "returns the latest compensation effective on or before a date" do
    employee = create(:employee, start_date: Date.new(2026, 1, 1))
    first = create(:compensation, employee:, effective_date: Date.new(2026, 1, 1))
    second = create(:compensation, employee:, effective_date: Date.new(2026, 7, 1))
    future = create(:compensation, employee:, effective_date: Date.new(2027, 1, 1))

    expect(employee.current_compensation(Date.new(2026, 6, 1))).to eq(first)
    expect(employee.current_compensation(Date.new(2026, 8, 1))).to eq(second)
    expect(employee.current_compensation(Date.new(2027, 2, 1))).to eq(future)
  end
end
