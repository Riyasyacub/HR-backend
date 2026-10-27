require "rails_helper"

RSpec.describe Payroll::MarkPaid do
  let(:run) { create(:payroll_run, status: "generated", calculation_status: "completed") }

  around { |example| travel_to(Date.new(2026, 12, 5)) { example.run } }

  it "marks a generated run paid on the given date (TC-S09-05)" do
    described_class.call(run, paid_on: Date.new(2026, 12, 1))

    expect(run.reload).to have_attributes(status: "paid", paid_on: Date.new(2026, 12, 1))
  end

  it "rejects a draft run" do
    run.update!(status: "draft")

    expect { described_class.call(run, paid_on: Date.current) }.to raise_error(described_class::NotPayable)
  end

  it "rejects a run that is already paid" do
    run.update!(status: "paid", paid_on: Date.new(2026, 12, 1))

    expect { described_class.call(run, paid_on: Date.current) }.to raise_error(described_class::NotPayable)
  end

  it "rejects a future or missing date" do
    expect { described_class.call(run, paid_on: Date.new(2026, 12, 6)) }.to raise_error(described_class::NotPayable)
    expect { described_class.call(run, paid_on: nil) }.to raise_error(described_class::NotPayable)
    expect(run.reload.status).to eq("generated")
  end
end
