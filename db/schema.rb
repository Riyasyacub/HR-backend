# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_27_105738) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_entries", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "change_set", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_audit_entries_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_entries_on_auditable"
  end

  create_table "compensation_components", force: :cascade do |t|
    t.bigint "compensation_id", null: false
    t.string "name", null: false
    t.decimal "annual_amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "compensation_id, lower((name)::text)", name: "index_compensation_components_on_compensation_and_name", unique: true
    t.index ["compensation_id"], name: "index_compensation_components_on_compensation_id"
    t.check_constraint "annual_amount > 0::numeric", name: "compensation_components_annual_amount_positive"
  end

  create_table "compensations", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "effective_date", null: false
    t.decimal "annual_ctc", precision: 12, scale: 2, null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_date"], name: "index_compensations_on_employee_id_and_effective_date", unique: true
    t.index ["employee_id"], name: "index_compensations_on_employee_id"
    t.check_constraint "annual_ctc > 0::numeric", name: "compensations_annual_ctc_positive"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_departments_on_lower_code", unique: true
    t.index "lower((name)::text)", name: "index_departments_on_lower_name", unique: true
  end

  create_table "employee_imports", force: :cascade do |t|
    t.bigint "uploaded_by_id", null: false
    t.string "mode", default: "create", null: false
    t.string "status", default: "queued", null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "imported_rows", default: 0, null: false
    t.jsonb "row_errors", default: [], null: false
    t.string "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uploaded_by_id"], name: "index_employee_imports_on_uploaded_by_id"
    t.check_constraint "mode::text = ANY (ARRAY['create'::character varying, 'update'::character varying]::text[])", name: "employee_imports_mode_known"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "employee_imports_status_known"
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "department_id", null: false
    t.string "employee_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "work_email", null: false
    t.string "country", null: false
    t.string "currency", null: false
    t.string "job_title", null: false
    t.date "start_date", null: false
    t.string "bank_name", null: false
    t.string "ifsc"
    t.string "account_number", null: false
    t.string "status", default: "onboarding", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "manager_id"
    t.string "phone"
    t.string "personal_email"
    t.text "address"
    t.string "emergency_contact"
    t.index "lower((employee_id)::text)", name: "index_employees_on_lower_employee_id", unique: true
    t.index "lower((work_email)::text)", name: "index_employees_on_lower_work_email", unique: true
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["user_id"], name: "index_employees_on_user_id", unique: true
    t.check_constraint "manager_id IS NULL OR manager_id <> id", name: "check_employees_manager_not_self"
  end

  create_table "leave_imports", force: :cascade do |t|
    t.bigint "uploaded_by_id", null: false
    t.string "status", default: "queued", null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "imported_rows", default: 0, null: false
    t.jsonb "row_errors", default: [], null: false
    t.string "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uploaded_by_id"], name: "index_leave_imports_on_uploaded_by_id"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying::text, 'processing'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "leave_imports_status_known"
  end

  create_table "leave_ledger_entries", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "leave_type_id", null: false
    t.bigint "leave_record_id"
    t.integer "year", null: false
    t.string "entry_type", null: false
    t.integer "days", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "leave_type_id", "year"], name: "idx_on_employee_id_leave_type_id_year_f62b9c3cc5"
    t.index ["employee_id", "leave_type_id", "year"], name: "index_leave_ledger_entries_one_entitlement", unique: true, where: "((entry_type)::text = 'entitlement'::text)"
    t.index ["employee_id"], name: "index_leave_ledger_entries_on_employee_id"
    t.index ["leave_record_id"], name: "index_leave_ledger_entries_on_leave_record_id"
    t.index ["leave_type_id"], name: "index_leave_ledger_entries_on_leave_type_id"
    t.check_constraint "days <> 0", name: "leave_ledger_entries_days_nonzero"
    t.check_constraint "entry_type::text = ANY (ARRAY['entitlement'::character varying::text, 'used'::character varying::text, 'reversal'::character varying::text])", name: "leave_ledger_entries_entry_type_known"
  end

  create_table "leave_records", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "leave_type_id", null: false
    t.bigint "leave_import_id"
    t.date "leave_date", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "leave_date"], name: "index_leave_records_on_employee_id_and_leave_date", unique: true
    t.index ["employee_id"], name: "index_leave_records_on_employee_id"
    t.index ["leave_import_id"], name: "index_leave_records_on_leave_import_id"
    t.index ["leave_type_id"], name: "index_leave_records_on_leave_type_id"
  end

  create_table "leave_types", force: :cascade do |t|
    t.string "name", null: false
    t.integer "default_entitlement"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_leave_types_on_lower_name", unique: true
    t.check_constraint "default_entitlement IS NULL OR default_entitlement >= 0", name: "leave_types_default_entitlement_non_negative"
  end

  create_table "payroll_lines", force: :cascade do |t|
    t.bigint "payroll_run_id", null: false
    t.bigint "employee_id", null: false
    t.string "country", null: false
    t.string "currency", null: false
    t.decimal "monthly_gross", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "working_days", null: false
    t.integer "unpaid_days", default: 0, null: false
    t.decimal "unpaid_deduction", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.jsonb "blocking_issues", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employee_code"
    t.string "employee_name"
    t.string "bank_name"
    t.string "ifsc"
    t.string "account_number"
    t.index ["employee_id"], name: "index_payroll_lines_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payroll_lines_on_payroll_run_id_and_employee_id", unique: true
    t.index ["payroll_run_id"], name: "index_payroll_lines_on_payroll_run_id"
  end

  create_table "payroll_runs", force: :cascade do |t|
    t.date "month", null: false
    t.string "status", default: "draft", null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "calculation_status", default: "queued", null: false
    t.string "calculation_error"
    t.date "paid_on"
    t.index ["created_by_id"], name: "index_payroll_runs_on_created_by_id"
    t.index ["month"], name: "index_payroll_runs_on_month", unique: true
    t.check_constraint "calculation_status::text = ANY (ARRAY['queued'::character varying::text, 'processing'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "payroll_runs_calculation_status_known"
    t.check_constraint "status::text <> 'paid'::text OR paid_on IS NOT NULL", name: "payroll_runs_paid_on_when_paid"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'generated'::character varying::text, 'paid'::character varying::text])", name: "payroll_runs_status_known"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "refresh_token_digest", null: false
    t.datetime "last_used_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["refresh_token_digest"], name: "index_user_sessions_on_refresh_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_user_sessions_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "country", null: false
    t.string "status", default: "active", null: false
    t.boolean "active", default: true, null: false
    t.integer "token_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_entries", "users", column: "actor_id"
  add_foreign_key "compensation_components", "compensations"
  add_foreign_key "compensations", "employees"
  add_foreign_key "employee_imports", "users", column: "uploaded_by_id"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "users"
  add_foreign_key "leave_imports", "users", column: "uploaded_by_id"
  add_foreign_key "leave_ledger_entries", "employees"
  add_foreign_key "leave_ledger_entries", "leave_records"
  add_foreign_key "leave_ledger_entries", "leave_types"
  add_foreign_key "leave_records", "employees"
  add_foreign_key "leave_records", "leave_imports"
  add_foreign_key "leave_records", "leave_types"
  add_foreign_key "payroll_lines", "employees"
  add_foreign_key "payroll_lines", "payroll_runs"
  add_foreign_key "payroll_runs", "users", column: "created_by_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "roles"
end
