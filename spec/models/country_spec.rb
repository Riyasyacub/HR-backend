require "rails_helper"

RSpec.describe Country do
  it "lists exactly India, USA, and Canada with their currencies" do
    expect(Country.all).to eq([
      { name: "India", currency: "INR" },
      { name: "USA", currency: "USD" },
      { name: "Canada", currency: "CAD" }
    ])
    expect(Country.all).to all(be_frozen)
    expect(Country.all).to be_frozen
  end

  it "derives the currency from the country" do
    expect(Country.currency_for("Canada")).to eq("CAD")
  end

  it "rejects an unsupported country" do
    expect { Country.currency_for("Germany") }
      .to raise_error(Country::Unsupported, "Germany")
  end
end
