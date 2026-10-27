require "rails_helper"

RSpec.describe "Employee imports", type: :request do
  let(:hr) { create(:user, :hr) }

  def xlsx_upload
    sheet = build_xlsx([ %w[employee_id first_name] ])
    Rack::Test::UploadedFile.new(sheet.path, EmployeeImport::XLSX_CONTENT_TYPE, original_filename: "employees.xlsx")
  end

  def upload(file, user = hr)
    post "/api/v1/employee_imports", params: { file: }.compact, headers: authentication_headers(user)
  end

  it "queues an uploaded Excel file for HR" do
    expect { upload(xlsx_upload) }.to have_enqueued_job(ImportEmployeeSheetJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body["data"]).to include("mode" => "create", "status" => "queued", "row_errors" => [])
    expect(EmployeeImport.last.uploaded_by).to eq(hr)
  end

  it "queues an update import, and rejects an unknown mode" do
    post "/api/v1/employee_imports", params: { file: xlsx_upload, mode: "update" }, headers: authentication_headers(hr)
    expect(response.parsed_body["data"]).to include("mode" => "update", "status" => "queued")

    post "/api/v1/employee_imports", params: { file: xlsx_upload, mode: "merge" }, headers: authentication_headers(hr)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to include("Mode is not included in the list")
  end

  it "rejects a file that is not an Excel workbook, or no file" do
    upload(Rack::Test::UploadedFile.new(StringIO.new("a,b"), "text/csv", original_filename: "employees.csv"))
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("code" => "validation_failed", "details" => [ "File must be an Excel (.xlsx) file" ])

    upload(nil)
    expect(response.parsed_body["error"]["details"]).to include("File can't be blank")
  end

  it "shows the import summary and row errors" do
    employee_import = create(:employee_import, status: "completed", total_rows: 2, imported_rows: 1,
      row_errors: [ { "line" => 3, "errors" => [ "unknown manager EMP999" ] } ])

    get "/api/v1/employee_imports/#{employee_import.id}", headers: authentication_headers(hr)

    expect(response.parsed_body["data"]).to include("status" => "completed", "total_rows" => 2, "imported_rows" => 1,
      "row_errors" => [ { "line" => 3, "errors" => [ "unknown manager EMP999" ] } ], "error_message" => nil)
  end

  it "paginates row errors with the total in meta" do
    errors = (2..121).map { |line| { "line" => line, "errors" => [ "employee_id EMP#{line} already exists" ] } }
    employee_import = create(:employee_import, status: "completed", total_rows: 120, row_errors: errors)

    get "/api/v1/employee_imports/#{employee_import.id}", params: { errors_page: 2, errors_per_page: 50 }, headers: authentication_headers(hr)

    expect(response.parsed_body["data"]["row_errors"].pluck("line")).to eq((52..101).to_a)
    expect(response.parsed_body["meta"]).to eq("row_errors_total" => 120, "errors_page" => 2, "errors_per_page" => 50)

    get "/api/v1/employee_imports/#{employee_import.id}", params: { errors_per_page: 1000 }, headers: authentication_headers(hr)
    expect(response.parsed_body["meta"]["errors_per_page"]).to eq(200)
  end

  it "downloads a template the parser accepts" do
    create(:department, name: "Engineering")

    get "/api/v1/employee_imports/template", headers: authentication_headers(hr)

    expect(response.headers["Content-Disposition"]).to include('filename="employee_template.xlsx"')
    file = Tempfile.new([ "template", ".xlsx" ]).tap { |f| f.binmode && f.write(response.body) && f.flush }
    expect(Roo::Excelx.new(file.path).sheet(0).row(1)).to eq(Employees::Template::HEADERS)
    expect(Employees::SheetParser.call(file.path).map(&:errors)).to eq([ [] ])
  end

  it "denies an employee upload, status and template" do
    employee_user = create(:user)
    employee_import = create(:employee_import)

    upload(xlsx_upload, employee_user)
    expect(response).to have_http_status(:forbidden)
    get "/api/v1/employee_imports/#{employee_import.id}", headers: authentication_headers(employee_user)
    expect(response).to have_http_status(:forbidden)
    get "/api/v1/employee_imports/template", headers: authentication_headers(employee_user)
    expect(response).to have_http_status(:forbidden)
  end
end
