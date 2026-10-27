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

  describe "reporting hierarchy" do
    let(:arjun) { create(:employee, employee_id: "EMP101", work_email: "arjun@demo.test") }
    let(:priya) { create(:employee, employee_id: "EMP102", work_email: "priya@demo.test", manager: arjun) }

    it "allows assigning an existing employee as manager" do
      expect(priya.manager).to eq(arjun)
      expect(arjun.subordinates).to include(priya)
    end

    it "allows leaving manager empty" do
      expect(arjun.manager).to be_nil
    end

    it "rejects setting self as manager" do
      arjun.manager = arjun

      expect(arjun).not_to be_valid
      expect(arjun.errors[:manager]).to include("cannot be yourself")
    end

    it "enforces self-management rejection in the database" do
      expect do
        arjun.update_column(:manager_id, arjun.id)
      end.to raise_error(ActiveRecord::StatementInvalid, /check_employees_manager_not_self/)
    end

    it "rejects direct reporting cycles" do
      arjun.manager = priya

      expect(arjun).not_to be_valid
      expect(arjun.errors[:manager]).to include("creates a reporting cycle")
    end

    it "rejects indirect reporting cycles" do
      meera = create(:employee, employee_id: "EMP103", work_email: "meera@demo.test", manager: nil)
      arjun.update!(manager: meera)
      # priya -> arjun -> meera. Attempting meera -> priya should fail
      meera.manager = priya

      expect(meera).not_to be_valid
      expect(meera.errors[:manager]).to include("creates a reporting cycle")
    end

    it "returns all subordinate ids recursively" do
      kavita = create(:employee, employee_id: "EMP104", work_email: "kavita@demo.test", manager: priya)
      meera = create(:employee, employee_id: "EMP103", work_email: "meera@demo.test")
      arjun.update!(manager: meera)
      # meera -> arjun -> priya -> kavita

      expect(meera.subordinate_ids).to match_array([ arjun.id, priya.id, kavita.id ])
      expect(arjun.subordinate_ids).to match_array([ priya.id, kavita.id ])
      expect(priya.subordinate_ids).to eq([ kavita.id ])
      expect(kavita.subordinate_ids).to be_empty
    end

    it "identifies managers by whether they have direct reports" do
      priya
      expect(arjun).to be_manager
      expect(priya).not_to be_manager
    end
  end

  describe "self-service contact fields" do
    it "accepts phone, personal email, address, and emergency contact" do
      employee = build(:employee,
        phone: "+91-98765-43210",
        personal_email: "ravi.personal@demo.test",
        address: "123 Main Street, Bangalore",
        emergency_contact: "+91-98765-00000")

      expect(employee).to be_valid
    end

    it "treats self-service fields as optional" do
      employee = build(:employee, phone: nil, personal_email: nil,
        address: nil, emergency_contact: nil)

      expect(employee).to be_valid
    end
  end
end
