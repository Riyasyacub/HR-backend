require "rails_helper"

RSpec.describe Assistant::Executor do
  let!(:arjun) { create(:employee, user: create(:user), first_name: "Arjun") }
  let!(:priya) { create(:employee, manager: arjun, first_name: "Priya") }
  let!(:robert) { create(:employee, first_name: "Robert") }
  let(:hr_schema) { Assistant::ScopedSchema.new(create(:user, :hr)) }

  def execute(sql, schema: hr_schema, relations: %w[employees], **options)
    described_class.call(sql, schema:, relations:, **options)
  end

  it "builds only the referenced CTEs" do
    expect(hr_schema.cte_sql(only: %w[employees])).to start_with("WITH employees AS (")
    expect(hr_schema.cte_sql(only: %w[employees])).not_to include("departments AS")
    expect(hr_schema.cte_sql(only: [])).to eq("")
  end

  it "returns columns and rows from the asker's scope (AC-01, AC-02)" do
    result = execute("SELECT first_name FROM employees ORDER BY first_name", schema: Assistant::ScopedSchema.new(arjun.user))

    expect(result).to have_attributes(columns: [ "first_name" ], rows: [ [ "Arjun" ], [ "Priya" ] ], truncated: false)
  end

  it "caps rows at the limit and flags truncation" do
    result = execute("SELECT first_name FROM employees ORDER BY first_name", limit: 2)

    expect(result).to have_attributes(rows: [ [ "Arjun" ], [ "Priya" ] ], truncated: true)
  end

  it "cannot change data and leaves the surrounding transaction writable (AC-04)" do
    expect { execute("SELECT nextval('employees_id_seq')", relations: []) }
      .to raise_error(described_class::QueryFailed, /read-only transaction/)
    expect { create(:department) }.not_to raise_error
  end

  it "stops a slow query" do
    expect { execute("SELECT pg_sleep(1)", relations: [], timeout: "50ms") }.to raise_error(described_class::Timeout)
  end

  it "reports a query that references a missing column" do
    expect { execute("SELECT salary FROM employees") }.to raise_error(described_class::QueryFailed, /column "salary" does not exist/)
  end
end
