require "rails_helper"

RSpec.describe "Application configuration" do
  it "boots the Rails application" do
    expect(Rails.application).to be_a(Rails::Application)
  end

  it "inserts Rack::Cors into the middleware stack" do
    middleware_names = Rails.application.middleware.map(&:name)

    expect(middleware_names).to include("Rack::Cors")
  end
end
