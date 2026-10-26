require "rails_helper"

RSpec.describe Compensation, type: :model do
  subject(:compensation) { build(:compensation) }

  it { is_expected.to be_valid }

  it "derives the currency from the employee" do
    expect(compensation.tap(&:validate).currency).to eq("INR")
  end

  it "keeps the currency snapshot after the employee changes country" do
    compensation.save!
    compensation.employee.update!(country: "USA")

    expect(compensation.reload.currency).to eq("INR")
    expect(build(:compensation, employee: compensation.employee).tap(&:validate).currency)
      .to eq("USD")
  end

  it "defaults the effective date to the employee start date" do
    employee = create(:employee, start_date: Date.new(2026, 1, 15))
    compensation = build(:compensation, employee:, effective_date: nil)

    compensation.validate

    expect(compensation.effective_date).to eq(employee.start_date)
  end

  it "derives annual CTC from its components" do
    compensation = build(:compensation, annual_ctc: nil,
      components_attributes: [
        { name: "Basic", annual_amount: 1_000_000 },
        { name: "Allowance", annual_amount: 200_000 }
      ])

    compensation.save!

    expect(compensation.reload.annual_ctc).to eq(BigDecimal("1200000"))
    expect(compensation.components.count).to eq(2)
  end

  it "requires an effective date and a positive annual CTC" do
    compensation.assign_attributes(employee: nil, effective_date: nil, annual_ctc: 0)

    expect(compensation).not_to be_valid
    expect(compensation.errors[:effective_date]).to be_present
    expect(compensation.errors[:annual_ctc]).to be_present
  end

  it "allows one compensation per employee and effective date" do
    existing = create(:compensation)
    duplicate = build(:compensation, employee: existing.employee,
      effective_date: existing.effective_date)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:effective_date]).to be_present
  end

  it "enforces one compensation per employee and effective date in the database" do
    existing = create(:compensation)
    duplicate = build(:compensation, employee: existing.employee,
      effective_date: existing.effective_date, currency: existing.currency)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "does not allow existing compensation rows to be changed" do
    compensation.save!

    compensation.update(annual_ctc: 1_500_000)

    expect(compensation).not_to be_valid
    expect(compensation.errors[:base]).to include("compensation history is append-only")
  end

  it "destroys components with the compensation" do
    compensation = create(:compensation)
    create(:compensation_component, compensation:)

    expect { compensation.destroy! }.to change(CompensationComponent, :count).by(-1)
  end
end
