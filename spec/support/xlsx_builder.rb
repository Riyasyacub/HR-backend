require "zip"

# Builds a minimal .xlsx in memory so specs can describe sheet contents inline.
# Date values are written as Excel serial numbers with a date style, like a real spreadsheet.
module XlsxBuilder
  EXCEL_EPOCH = Date.new(1899, 12, 30)

  def build_xlsx(rows)
    file = Tempfile.new([ "leave", ".xlsx" ])
    file.binmode
    file.write(xlsx_bytes(rows))
    file.rewind
    file
  end

  private

  def xlsx_bytes(rows)
    Zip::OutputStream.write_buffer do |zip|
      xlsx_parts(rows).each do |name, xml|
        zip.put_next_entry(name)
        zip.write(xml)
      end
    end.string
  end

  def xlsx_parts(rows)
    {
      "[Content_Types].xml" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
      XML
      "_rels/.rels" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
      XML
      "xl/workbook.xml" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Leave" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
      XML
      "xl/_rels/workbook.xml.rels" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
      XML
      "xl/styles.xml" => <<~XML,
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="1"><font/></fonts><fills count="1"><fill/></fills><borders count="1"><border/></borders>
          <cellStyleXfs count="1"><xf/></cellStyleXfs>
          <cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/></cellXfs>
        </styleSheet>
      XML
      "xl/worksheets/sheet1.xml" => sheet_xml(rows)
    }
  end

  def sheet_xml(rows)
    body = rows.each_with_index.map do |row, row_index|
      cells = row.each_with_index.map { |value, col_index| cell_xml(value, "#{('A'.ord + col_index).chr}#{row_index + 1}") }
      "<row r=\"#{row_index + 1}\">#{cells.join}</row>"
    end
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>#{body.join}</sheetData></worksheet>
    XML
  end

  def cell_xml(value, ref)
    case value
    when nil then ""
    when Date then "<c r=\"#{ref}\" s=\"1\"><v>#{(value - EXCEL_EPOCH).to_i}</v></c>"
    when Numeric then "<c r=\"#{ref}\"><v>#{value}</v></c>"
    else "<c r=\"#{ref}\" t=\"inlineStr\"><is><t>#{ERB::Util.html_escape(value)}</t></is></c>"
    end
  end
end

RSpec.configure { |config| config.include XlsxBuilder }
