class LeaveLedgerEntry < ApplicationRecord
  ENTRY_TYPES = %w[entitlement used reversal].freeze

  belongs_to :employee
  belongs_to :leave_type
  belongs_to :leave_record, optional: true

  validates :year, :days, presence: true
  validates :entry_type, inclusion: { in: ENTRY_TYPES }

  def self.balance(employee:, leave_type:, year:)
    where(employee:, leave_type:, year:).sum(:days)
  end

  def self.summary(employee:, year:)
    balance_rows(where(employee:, year:).group(:leave_type_id, :entry_type).sum(:days))
  end

  # totals is keyed by [leave_type_id, entry_type]; pass tracked_types when building many rows.
  def self.balance_rows(totals, tracked_types = LeaveType.where.not(default_entitlement: nil).order(:id))
    tracked_types.map do |leave_type|
      entitled = totals.fetch([ leave_type.id, "entitlement" ], 0)
      used = -(totals.fetch([ leave_type.id, "used" ], 0) + totals.fetch([ leave_type.id, "reversal" ], 0))
      { "leave_type" => leave_type.name, "entitled" => entitled, "used" => used, "remaining" => entitled - used }
    end
  end

  def readonly? = persisted?
end
