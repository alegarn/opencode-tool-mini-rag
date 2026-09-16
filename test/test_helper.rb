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
  # Real 32x32 gradient JPEG (731 bytes) — DCTDecode passthrough payloads must
  # be actual JPEG file bytes.
  TINY_JPEG = [ "ffd8ffe000104a46494600010100000100010000ffdb0043000a07070807060a0808080b0a0a0b0e18100e0d0d0e1d15161118231f2524221f2221262b372f26293429212230413134393b3e3e3e252e4449433c48373d3e3bffdb0043010a0b0b0e0d0e1c10101c3b2822283b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3bffc00011080020002003012200021101031101ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c03010002110311003f00f2f82cba715a505974e2afc165d38ad282cba714464183c61420b2e9c569c165d38abd05974e2b4e0b2e9c5744647d7e0f19b6a64c165d38ad282cba7157e0b2e9c5694165d38af3e323f21c1e336d4a105974e2b4e0b2e9c55e82cba715a705974e2ba2323ebf078c3fffd9" ].pack("H*")

  def with_pdf(pages, info: {})
    Tempfile.create([ "test", ".pdf" ]) do |file|
      file.binmode
      file.write(build_pdf(pages, info:))
      file.flush
      yield file.path
    end
  end

  private

  # A page is either an Array of text lines or a Hash with :lines and :images
  # (image: { name:, width:, height:, filter:, data:, color_space:, bits: }).
  # info: { Title: "...", Author: "...", ... } lands in the document Info
  # dict; nil values serialize as PDF null (parsed back as nil).
  def build_pdf(pages, info: {})
    entries = pages.map { |page| page.is_a?(Hash) ? page : { lines: page } }
    page_count = entries.size
    next_object_id = 3 + 2 * page_count
    image_object_ids = entries.map do |entry|
      Array(entry[:images]).map do
        object_id = next_object_id
        next_object_id += 1
        object_id
      end
    end

    objects = []
    objects << "<< /Type /Catalog /Pages 2 0 R >>"
    objects << "<< /Type /Pages /Kids [#{(0...page_count).map { |i| "#{3 + 2 * i} 0 R" }.join(" ")}] /Count #{page_count} >>"
    entries.each_with_index do |entry, i|
      xobjects = Array(entry[:images]).each_with_index
                                           .map { |image, j| "/#{image[:name]} #{image_object_ids[i][j]} 0 R" }
                                           .join(" ")
      resources = "<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >> >>#{' /XObject << ' + xobjects + ' >>' unless xobjects.empty?} >>"
      objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents #{4 + 2 * i} 0 R /Resources #{resources} >>"
      objects << content_object(Array(entry[:lines]))
    end
    entries.each_with_index do |entry, i|
      Array(entry[:images]).each_with_index do |image, j|
        objects[image_object_ids[i][j] - 1] = image_object(image)
      end
    end
    info_id = info.any? ? objects.size + 1 : nil
    objects << info_object(info) if info_id
    serialize_pdf(objects, info_id:)
  end

  def info_object(info)
    entries = info.map { |key, value| value.nil? ? "/#{key} null" : "/#{key} (#{escape(value)})" }.join(" ")
    "<< #{entries} >>"
  end

  def content_object(lines)
    stream = lines.each_with_index.map { |line, j| "BT\n/F1 12 Tf\n72 #{720 - 20 * j} Td\n(#{escape(win_ansi(line))}) Tj\nET" }.join("\n")
    "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
  end

  # Standard-14 fonts default to WinAnsiEncoding: write text bytes as
  # Windows-1252 so pdf-reader decodes accents back to proper UTF-8.
  def win_ansi(line)
    line.to_s.encode("Windows-1252")
  end

  def image_object(image)
    filter = " /Filter /#{image[:filter]}" if image[:filter]
    dict = "<< /Type /XObject /Subtype /Image /Width #{image[:width]} /Height #{image[:height]}" \
           " /ColorSpace /#{image.fetch(:color_space, "DeviceRGB")} /BitsPerComponent #{image.fetch(:bits, 8)}#{filter}" \
           " /Length #{image[:data].bytesize} >>"
    "#{dict}\nstream\n#{image[:data]}\nendstream"
  end

  def escape(line)
    line.gsub(/([\\()])/) { "\\#{Regexp.last_match(1)}" }
  end

  def serialize_pdf(objects, info_id: nil)
    out = "%PDF-1.4\n".b
    offsets = []
    objects.each_with_index do |body, i|
      offsets << out.bytesize
      out << "#{i + 1} 0 obj\n#{body}\nendobj\n"
    end
    xref = out.bytesize
    out << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| out << format("%010d 00000 n \n", offset) }
    info_ref = " /Info #{info_id} 0 R" if info_id
    out << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R#{info_ref} >>\nstartxref\n#{xref}\n%%EOF\n"
    out
  end
end

ActiveSupport::TestCase.include PdfHelper
