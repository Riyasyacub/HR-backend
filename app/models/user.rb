class User < ApplicationRecord
  COUNTRIES = %w[India USA Canada].freeze
  STATUSES = %w[onboarding active notice exited].freeze

  has_secure_password

  belongs_to :role
  has_many :user_sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, :country, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country, inclusion: { in: COUNTRIES }
  validates :status, inclusion: { in: STATUSES }
  validates :active, inclusion: { in: [ true, false ] }
  validates :password, length: { minimum: 8 }, allow_nil: true

  delegate :hr?, :standard_employee?, to: :role
end
