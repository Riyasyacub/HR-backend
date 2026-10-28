class AssistantQuery < ApplicationRecord
  STATUSES = %w[answered cached rejected failed].freeze

  belongs_to :user

  validates :question, presence: true, length: { maximum: 500 }
  validates :status, inclusion: { in: STATUSES }

  def readonly? = persisted?
end
