class Department < ApplicationRecord
  has_many :employees, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.strip }
  normalizes :code, with: ->(code) { code.strip.upcase }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :code, presence: true, uniqueness: { case_sensitive: false }
end
