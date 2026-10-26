class LeaveType < ApplicationRecord
  NAMES = %w[Earned Sick Casual Unpaid].freeze
  BALANCED_NAMES = (NAMES - [ "Unpaid" ]).freeze
  DEFAULT_ENTITLEMENTS = { "Earned" => 6, "Sick" => 6, "Casual" => 6, "Unpaid" => nil }.freeze

  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }
  validates :default_entitlement, numericality: {
    only_integer: true, greater_than_or_equal_to: 0
  }, allow_nil: true
  validate :entitlement_for_balance_tracking
  def self.ordered = all.sort_by { |leave_type| NAMES.index(leave_type.name) }
  def balance_tracked? = BALANCED_NAMES.include?(name)

  private

  def entitlement_for_balance_tracking
    if BALANCED_NAMES.include?(name)
      errors.add(:default_entitlement, "can't be blank") if default_entitlement.nil?
    elsif name == "Unpaid" && !default_entitlement.nil?
      errors.add(:default_entitlement, "must be blank for unpaid leave")
    end
  end
end
