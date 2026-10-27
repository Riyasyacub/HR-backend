require "rails_helper"

RSpec.describe "Leave imports", type: :request do
  include ActiveJob::TestHelper

  let(:hr) { create(:user, :hr) }
  let(:employee_user) { create(:user) }

  def xlsx_upload
    sheet = build_xlsx([ %w[employee_id leave_date leave_type] ])
    Rack::Test::UploadedFile.new(sheet.path, LeaveImport::XLSX_CONTENT_TYPE, original_filename: "leave.xlsx")
  end

  def upload(file, user = hr)
    post "/api/v1/leave_imports", params: { file: }, headers: authentication_headers(user)
  end

  it "queues an uploaded Excel file for HR" do
    expect { upload(xlsx_upload) }.to have_enqueued_job(ImportLeaveSheetJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body["data"]).to include("status" => "queued", "total_rows" => 0, "row_errors" => [])
    expect(LeaveImport.last.uploaded_by).to eq(hr)
  end

  it "rejects a file that is not an Excel workbook" do
    upload(Rack::Test::UploadedFile.new(StringIO.new("a,b"), "text/csv", original_filename: "leave.csv"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("code" => "validation_failed",
      "details" => [ "File must be an Excel (.xlsx) file" ])
  end

  it "rejects an upload without a file" do
    post "/api/v1/leave_imports", headers: authentication_headers(hr)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to include("File can't be blank")
  end

  it "returns the import status with row errors for HR" do
    leave_import = create(:leave_import, status: "completed", total_rows: 2, imported_rows: 1,
      row_errors: [ { "line" => 3, "errors" => [ "unknown employee EMP999" ] } ])

    get "/api/v1/leave_imports/#{leave_import.id}", headers: authentication_headers(hr)

    expect(response.parsed_body["data"]).to include("id" => leave_import.id, "status" => "completed",
      "total_rows" => 2, "imported_rows" => 1, "error_message" => nil,
      "row_errors" => [ { "line" => 3, "errors" => [ "unknown employee EMP999" ] } ])
  end

  it "denies an employee upload and stores nothing (TC-S06-08, AC-08)" do
    expect { upload(xlsx_upload, employee_user) }.not_to change(LeaveImport, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "denies an employee the import status" do
    get "/api/v1/leave_imports/#{create(:leave_import).id}", headers: authentication_headers(employee_user)

    expect(response).to have_http_status(:forbidden)
  end

  it "downloads the Excel template for HR" do
    get "/api/v1/leave_imports/template", headers: authentication_headers(hr)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(LeaveImport::XLSX_CONTENT_TYPE)
    expect(response.headers["Content-Disposition"]).to include('attachment; filename="leave_template.xlsx"')
  end

  it "denies an employee the template" do
    get "/api/v1/leave_imports/template", headers: authentication_headers(employee_user)

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an unauthenticated upload" do
    post "/api/v1/leave_imports", params: { file: xlsx_upload }

    expect(response).to have_http_status(:unauthorized)
  end
end
