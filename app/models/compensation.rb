class Compensation < ApplicationRecord
  belongs_to :employee, inverse_of: :compensations
  has_many :components, class_name: "CompensationComponent",
    dependent: :destroy, inverse_of: :compensation
  accepts_nested_attributes_for :components

  before_validation :set_currency_from_employee
  before_validation { self.effective_date ||= employee&.start_date }
  before_validation :derive_annual_ctc

  validates :effective_date, :currency, presence: true
  validates :effective_date, uniqueness: { scope: :employee_id }
  validates :annual_ctc, numericality: { greater_than: 0 }
  validate :append_only, on: :update

  private

  def set_currency_from_employee
    self.currency = employee&.currency
    self.currency ||= Country.currency_for(employee.country) if employee
  rescue Country::Unsupported
    self.currency = nil
  end

  def derive_annual_ctc
    return if components.empty?

    self.annual_ctc = components.sum { |component| component.annual_amount || 0 }
  end

  def append_only
    errors.add(:base, "compensation history is append-only")
  end
end
