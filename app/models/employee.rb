class Employee < ApplicationRecord
  STATUSES = %w[onboarding active].freeze

  belongs_to :department
  belongs_to :user, optional: true
  has_many :compensations, dependent: :restrict_with_exception, inverse_of: :employee

  normalizes :employee_id, with: ->(employee_id) { employee_id.strip.upcase }
  normalizes :work_email, with: ->(work_email) { work_email.strip.downcase }

  before_validation :set_currency_from_country

  validates :employee_id, :first_name, :last_name, :work_email, :job_title,
    :start_date, :status, :currency, :bank_name, :account_number, presence: true
  validates :employee_id, :work_email, uniqueness: { case_sensitive: false }
  validates :work_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country, inclusion: { in: Country.names }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: true, allow_nil: true
  validate :immutable_identity_fields, on: :update

  def current_compensation(on = Date.current)
    compensations.where(effective_date: ..on).order(effective_date: :desc).first
  end

  private

  def set_currency_from_country
    self.currency = Country.currency_for(country)
  rescue Country::Unsupported
    self.currency = nil
  end

  def immutable_identity_fields
    errors.add(:employee_id, "can't be changed") if employee_id_changed?
    errors.add(:work_email, "can't be changed") if work_email_changed?
  end
end
