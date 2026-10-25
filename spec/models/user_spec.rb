require "rails_helper"

RSpec.describe User, type: :model do
  it "stores a bcrypt digest and authenticates the password" do
    user = create(:user, password: "Demo@1234")

    expect(user.password_digest).to start_with("$2")
    expect(user.password_digest).not_to include("Demo@1234")
    expect(user.authenticate("Demo@1234")).to eq(user)
    expect(user.authenticate("wrong-password")).to be(false)
  end

  it "normalises the email and rejects a duplicate case-insensitively" do
    create(:user, email: "Priya@Demo.Test")

    duplicate = build(:user, email: " priya@demo.test ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "requires a supported country" do
    user = build(:user, country: "Germany")

    expect(user).not_to be_valid
    expect(user.errors[:country]).to be_present
  end

  it "identifies HR users through their role" do
    expect(create(:user, :hr)).to be_hr
    expect(create(:user)).not_to be_hr
  end

  it "defaults the token version to zero and the account to active" do
    user = create(:user)

    expect(user.token_version).to eq(0)
    expect(user).to be_active
  end
end
