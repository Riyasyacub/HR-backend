class Department < ApplicationRecord
  normalizes :name, with: ->(name) { name.strip }
  normalizes :code, with: ->(code) { code.strip.upcase }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :code, presence: true, uniqueness: { case_sensitive: false }
end
