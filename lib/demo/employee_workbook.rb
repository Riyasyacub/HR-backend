module Demo
  class EmployeeWorkbook
    HEADERS = Employees::Template::HEADERS
    DEPARTMENTS = { "ENG" => "Engineering", "FIN" => "Finance", "HRM" => "Human Resources", "SAL" => "Sales", "OPS" => "Operations" }.freeze
    COUNTRY_SHARE = { "India" => 0.6, "USA" => 0.25, "Canada" => 0.15 }.freeze
    ANNUAL_CTC = { "India" => 400_000..3_000_000, "USA" => 60_000..200_000, "Canada" => 55_000..170_000 }.freeze
    HEADS = { "India" => "EMP103", "USA" => "EMP104", "Canada" => "EMP106" }.freeze
    DEMO_EMPLOYEES = [
      %w[EMP101 Priya Sharma priya India EMP102], %w[EMP102 Arjun Rao arjun India EMP103], [ "EMP103", "Meera", "Nair", "meera", "India", nil ],
      [ "EMP104", "Robert", "Miller", "robert", "USA", nil ], %w[EMP105 John Davis john USA EMP104],
      [ "EMP106", "Carol", "Smith", "carol", "Canada", nil ], %w[EMP107 Emily Brown emily Canada EMP106]
    ].freeze
    REPORTS_PER_MANAGER = 5
    COLUMN_TYPES = [ *Array.new(7, :string), :date, *Array.new(6, :string), :integer, :integer, :integer ].freeze

    def self.ensure_departments = DEPARTMENTS.each { |code, name| Department.find_or_create_by!(code:) { _1.name = name } }

    def self.write(path, size:)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Employees") do |sheet|
        sheet.add_row HEADERS
        rows(size:).each { |row| sheet.add_row row, types: COLUMN_TYPES }
      end
      File.binwrite(path, package.to_stream.read)
    end

    def self.rows(size:)
      random = Random.new(42)
      Faker::Config.random = random
      demo = DEMO_EMPLOYEES.map { |id, first, last, login, country, manager| row(random, id, first, last, "#{login}@demo.test", country, manager) }
      demo + seeded_rows(random, size)
    ensure
      Faker::Config.random = nil
    end

    def self.seeded_rows(random, size)
      counts = { "India" => (size * COUNTRY_SHARE["India"]).round, "USA" => (size * COUNTRY_SHARE["USA"]).round }
      counts["Canada"] = size - counts.values.sum
      number = 0
      counts.flat_map do |country, count|
        ids = Array.new(count) { format("SEED%05d", number += 1) }
        ids.each_with_index.map do |id, index|
          manager = index < REPORTS_PER_MANAGER ? HEADS[country] : ids[(index / REPORTS_PER_MANAGER) - 1]
          row(random, id, Faker::Name.first_name, Faker::Name.last_name, "#{id.downcase}@demo.test", country, manager)
        end
      end
    end

    def self.row(random, id, first, last, email, country, manager)
      ctc = random.rand(ANNUAL_CTC[country]).round(-3)
      basic = (ctc * 0.5).round(-3)
      hra = (ctc * 0.2).round(-3)
      [ id, first, last, email, country, DEPARTMENTS.values[random.rand(DEPARTMENTS.size)], Faker::Job.title,
        Date.new(2018, 1, 1) + random.rand(3000), country == "India" ? "HDFC Bank" : "First National Bank",
        random.rand(10**11..(10**12) - 1).to_s, manager, country == "India" ? "HDFC0#{random.rand(100_000..999_999)}" : nil,
        nil, nil, basic, hra, ctc - basic - hra ]
    end
    private_class_method :seeded_rows, :row
  end
end
