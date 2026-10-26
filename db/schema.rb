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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_105142) do
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

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_departments_on_lower_code", unique: true
    t.index "lower((name)::text)", name: "index_departments_on_lower_name", unique: true
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
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "roles"
end
