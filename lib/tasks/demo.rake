namespace :demo do
  desc "Write the demo employee workbook for the employee import (default 10,000 seeded employees)"
  task :employee_workbook, [ :size ] => :environment do |_task, args|
    size = Integer(args.fetch(:size, 10_000))
    path = Rails.root.join("tmp/demo/employees_#{size}.xlsx")
    FileUtils.mkdir_p(path.dirname)
    Demo::EmployeeWorkbook.ensure_departments
    Demo::EmployeeWorkbook.write(path, size:)
    puts "Wrote #{path} (#{size} seeded + #{Demo::EmployeeWorkbook::DEMO_EMPLOYEES.size} demo employees)"
  end

  desc "Seed leave for the last two months for a sample of active employees (idempotent)"
  task seed_leave: :environment do
    puts "Created #{Demo::LeaveSeed.call} leave records"
  end
end
