class Api::V1::Settings::CountriesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
  def index
    authorize Country, :index?
    countries = Country.all
    render json: { data: countries, meta: { page: 1, per_page: countries.size, total: countries.size } }
  end
end
