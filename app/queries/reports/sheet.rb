module Reports
  class Sheet
    def self.to_xlsx(headers, rows)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Report") do |sheet|
        sheet.add_row headers
        rows.each { |row| sheet.add_row row }
      end
      package.to_stream.read
    end
  end
end
