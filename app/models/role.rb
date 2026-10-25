class Role < ApplicationRecord
  STANDARD_EMPLOYEE = "standard_employee"
  HR = "HR"
  NAMES = [ STANDARD_EMPLOYEE, HR ].freeze

  has_many :users, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }

  def hr? = name == HR
  def standard_employee? = name == STANDARD_EMPLOYEE
end
