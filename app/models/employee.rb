class Employee < ApplicationRecord
  STATUSES = %w[onboarding active].freeze

  belongs_to :department
  belongs_to :user, optional: true
  belongs_to :manager, class_name: "Employee", optional: true
  has_many :compensations, dependent: :restrict_with_exception, inverse_of: :employee
  has_many :leave_records, dependent: :restrict_with_exception
  has_many :subordinates, class_name: "Employee", foreign_key: :manager_id,
                          dependent: :restrict_with_exception, inverse_of: :manager

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
  validates :manager, presence: { message: "must exist" }, if: :manager_id?
  validate :immutable_identity_fields, on: :update
  validate :manager_cannot_be_self_or_subordinate

  def manager?
    subordinates.exists?
  end

  def subordinate_ids
    return [] unless persisted?

    query = <<~SQL.squish
      WITH RECURSIVE tree AS (
        SELECT id FROM employees WHERE manager_id = :id
        UNION ALL
        SELECT e.id FROM employees e INNER JOIN tree t ON e.manager_id = t.id
      ) SELECT id FROM tree
    SQL
    self.class.connection.select_values(self.class.sanitize_sql([ query, { id: } ])).map(&:to_i)
  end

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

  def manager_cannot_be_self_or_subordinate
    return if manager_id.blank?

    if manager_id == id
      errors.add(:manager, "cannot be yourself")
      return
    end

    return unless manager

    curr = manager
    while curr
      if curr.id == id
        errors.add(:manager, "creates a reporting cycle")
        break
      end
      curr = curr.manager
    end
  end
end
