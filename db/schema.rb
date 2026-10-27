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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "leave_types", force: :cascade do |t|
    t.string "name", null: false
    t.integer "default_entitlement"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_leave_types_on_lower_name", unique: true
    t.check_constraint "default_entitlement IS NULL OR default_entitlement >= 0", name: "leave_types_default_entitlement_non_negative"
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

  add_foreign_key "audit_entries", "users", column: "actor_id"
  add_foreign_key "compensation_components", "compensations"
  add_foreign_key "compensations", "employees"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "users"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "roles"
end
