require "rails_helper"

RSpec.describe Assistant::SqlValidator do
  let(:allowed) { %w[employees departments leave_records] }

  def validate(sql) = described_class.call(sql, allowed_relations: allowed)

  def expect_unsafe(sql, message)
    expect { validate(sql) }.to raise_error(described_class::Unsafe, message)
  end

  it "accepts one SELECT over allowed relations and returns the relations it uses" do
    sql = <<~SQL
      WITH recent AS (SELECT employee_id FROM leave_records WHERE leave_date >= current_date - 30)
      SELECT d.name, count(*), round(avg(extract(year FROM age(e.start_date))), 1), date_trunc('month', max(e.start_date))
      FROM employees e JOIN departments d ON d.id = e.department_id
      WHERE e.id IN (SELECT employee_id FROM recent) GROUP BY d.name
    SQL

    expect(validate(sql)).to contain_exactly("employees", "departments", "leave_records")
    expect(validate("SELECT trim(first_name), substring(first_name FROM 1 FOR 2) FROM employees")).to eq(%w[employees])
  end

  it "rejects writes and DDL" do
    [ "DELETE FROM employees", "UPDATE employees SET first_name = 'x'", "INSERT INTO departments (name) VALUES ('x')",
      "DROP TABLE employees" ].each { |sql| expect_unsafe(sql, "Only a single SELECT statement is allowed") }
  end

  it "rejects multiple statements and SQL that does not parse" do
    expect_unsafe("SELECT 1; SELECT 2", "Only a single SELECT statement is allowed")
    expect_unsafe("SELEC id FROM employees", "Generated SQL could not be parsed")
  end

  it "rejects unknown relations and system catalogs" do
    expect_unsafe("SELECT * FROM compensations", "Relation not allowed: compensations")
    expect_unsafe("SELECT * FROM pg_user", "Relation not allowed: pg_user")
    expect_unsafe("SELECT * FROM information_schema.tables", "Schema-qualified names are not allowed")
  end

  it "rejects schema-qualified names" do
    expect_unsafe("SELECT * FROM public.employees", "Schema-qualified names are not allowed")
  end

  it "rejects functions outside the allowlist" do
    expect_unsafe("SELECT pg_sleep(10)", "Function not allowed: pg_sleep")
    expect_unsafe("SELECT current_setting('app.user_id')", "Function not allowed: current_setting")
    expect_unsafe("SELECT pg_read_file('/etc/passwd')", "Function not allowed: pg_read_file")
    expect_unsafe("SELECT pg_catalog.now()", "Function not allowed: pg_catalog.now")
  end

  it "rejects locking clauses and SELECT INTO" do
    expect_unsafe("SELECT * FROM employees FOR UPDATE", "Locking and SELECT INTO are not allowed")
    expect_unsafe("SELECT * INTO copy FROM employees", "Locking and SELECT INTO are not allowed")
  end

  it "rejects reg* casts that reveal catalog objects" do
    expect_unsafe("SELECT 'pg_user'::regclass", "Casts to reg* types are not allowed")
  end

  it "accepts a recursive hierarchy query" do
    sql = <<~SQL
      WITH RECURSIVE chain AS (
        SELECT id, id AS top_id FROM employees WHERE manager_id IS NULL
        UNION ALL SELECT e.id, c.top_id FROM employees e JOIN chain c ON e.manager_id = c.id
      ) SELECT t.first_name, count(*) FROM chain c JOIN employees t ON t.id = c.top_id GROUP BY t.first_name
    SQL

    expect(validate(sql)).to eq(%w[employees])
  end
end
