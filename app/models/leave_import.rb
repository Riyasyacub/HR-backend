class LeaveImport < ApplicationRecord
  STATUSES = %w[queued processing completed failed].freeze
  XLSX_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze
  MAX_FILE_SIZE = 5.megabytes

  belongs_to :uploaded_by, class_name: "User"
  has_one_attached :file

  validates :file, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :file_is_small_excel_workbook

  private

  def file_is_small_excel_workbook
    return unless file.attached?

    errors.add(:file, "must be an Excel (.xlsx) file") unless file.blob.content_type == XLSX_CONTENT_TYPE
    errors.add(:file, "must be 5 MB or smaller") if file.blob.byte_size > MAX_FILE_SIZE
  end
end
