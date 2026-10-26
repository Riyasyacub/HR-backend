class CompensationComponent < ApplicationRecord
  belongs_to :compensation, inverse_of: :components

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true,
    uniqueness: { scope: :compensation_id, case_sensitive: false }
  validates :annual_amount, numericality: { greater_than: 0 }
end
