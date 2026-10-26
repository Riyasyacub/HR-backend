require "rails_helper"

RSpec.describe Department, type: :model do
  it "normalises the name and code" do
    department = create(:department, name: "  Engineering  ", code: " eng ")

    expect(department.name).to eq("Engineering")
    expect(department.code).to eq("ENG")
  end

  it "rejects a duplicate name case-insensitively" do
    create(:department, name: "Engineering")

    duplicate = build(:department, name: "engineering")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "requires a name and a code" do
    department = build(:department, name: "", code: "")

    expect(department).not_to be_valid
    expect(department.errors[:name]).to be_present
    expect(department.errors[:code]).to be_present
  end

  it "enforces case-insensitive name uniqueness in the database" do
    create(:department, name: "Engineering", code: "ENG")

    duplicate = build(:department, name: "engineering", code: "OTHER")

    expect { duplicate.save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
