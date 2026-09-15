ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "tempfile"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module PdfHelper
  def with_pdf(pages)
    Tempfile.create([ "test", ".pdf" ]) do |file|
      file.binmode
      file.write(build_pdf(pages))
      file.flush
      yield file.path
    end
  end

  private

  def build_pdf(pages)
    n = pages.size
    page_ids = (0...n).map { |i| "#{3 + 2 * i} 0 R" }.join(" ")
    objects = []
    objects << "<< /Type /Catalog /Pages 2 0 R >>"
    objects << "<< /Type /Pages /Kids [#{page_ids}] /Count #{n} >>"
    pages.each_with_index do |lines, i|
      stream = lines.each_with_index.map { |line, j| "BT\n/F1 12 Tf\n72 #{720 - 20 * j} Td\n(#{escape(line)}) Tj\nET" }.join("\n")
      objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents #{4 + 2 * i} 0 R /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> >>"
      objects << "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
    end
    serialize_pdf(objects)
  end

  def escape(line)
    line.gsub(/([\\()])/) { "\\#{Regexp.last_match(1)}" }
  end

  def serialize_pdf(objects)
    out = +"%PDF-1.4\n"
    offsets = []
    objects.each_with_index do |body, i|
      offsets << out.bytesize
      out << "#{i + 1} 0 obj\n#{body}\nendobj\n"
    end
    xref = out.bytesize
    out << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| out << format("%010d 00000 n \n", offset) }
    out << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
    out
  end
end

ActiveSupport::TestCase.include PdfHelper
