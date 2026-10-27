class EmployeeImport < ApplicationRecord
  MODES = %w[create update].freeze
  STATUSES = %w[queued processing completed failed].freeze
  XLSX_CONTENT_TYPE = Mime[:xlsx].to_s
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :uploaded_by, class_name: "User"
  has_one_attached :file

  validates :file, presence: true
  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }
  validate :file_is_excel_workbook_within_limit

  private

  def file_is_excel_workbook_within_limit
    return unless file.attached?

    errors.add(:file, "must be an Excel (.xlsx) file") unless file.blob.content_type == XLSX_CONTENT_TYPE
    errors.add(:file, "must be 10 MB or smaller") if file.blob.byte_size > MAX_FILE_SIZE
  end
end
