require "test_helper"

class Image::ExtractorTest < ActiveSupport::TestCase
  test "rows carry the full image provenance without bytes" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    pages = [ { lines: [ "plain body text", "Figure 1: First caption" ],
                images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] } ]

    rows = with_pdf(pages) do |path|
      Image::Extractor.new(document, path).rows
    end

    assert_equal [ %i[document_id page section_path caption name content_type width height color_space filter digest] ], rows.map { |row| row.keys }
    row = rows.first
    assert_equal document.id, row[:document_id]
    assert_equal 1, row[:page]
    assert_equal "Im0", row[:name]
    assert_equal "image/jpeg", row[:content_type]
    assert_equal 200, row[:width]
    assert_equal 100, row[:height]
    assert_equal "DeviceRGB", row[:color_space]
    assert_equal "DCTDecode", row[:filter]
    assert_equal Digest::SHA256.hexdigest(PdfHelper::TINY_JPEG), row[:digest]
  end

  test "zips images with captions 1:1 in order, surplus dropped on both sides" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    pages = [
      { lines: [ "Figure 1: First caption", "Figure 2: Second caption", "Figure 3: Surplus caption" ],
        images: [ image("Im0"), image("Im1") ] },
      { lines: [ "plain body text line", "Diagram 9: Only caption" ],
        images: [ image("Im0", filter: "FlateDecode", data: compressed_pixels), image("Im1", filter: "FlateDecode", data: compressed_pixels) ] }
    ]

    rows = with_pdf(pages) do |path|
      Image::Extractor.new(document, path).rows
    end

    assert_equal [ "Figure 1: First caption", "Figure 2: Second caption" ], rows.first(2).map { |row| row[:caption] }
    assert_equal [ "Diagram 9: Only caption", nil ], rows.last(2).map { |row| row[:caption] }
  end

  test "DCTDecode and JPXDecode pass through bytes, other filters stay metadata-only" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    jpx = "\x00\x00\x00\x0cjP \r\n\x87".b
    pages = [ { lines: [ "plain body text" ],
                images: [ image("Im0", filter: "DCTDecode", data: PdfHelper::TINY_JPEG),
                          image("Im1", width: 150, height: 150, filter: "FlateDecode", data: compressed_pixels),
                          image("Im2", filter: "JPXDecode", data: jpx) ] } ]

    rows, files = with_pdf(pages) do |path|
      extractor = Image::Extractor.new(document, path)
      [ extractor.rows, extractor.files ]
    end

    dct = rows.find { |row| row[:name] == "Im0" }
    flate = rows.find { |row| row[:name] == "Im1" }
    jpx_row = rows.find { |row| row[:name] == "Im2" }

    assert_equal "image/jpeg", dct[:content_type]
    assert_equal Digest::SHA256.hexdigest(PdfHelper::TINY_JPEG), dct[:digest]
    assert_nil flate[:content_type]
    assert_equal "Im1:150x150", flate[:digest]
    assert_equal "image/jp2", jpx_row[:content_type]

    jpeg_digest = Digest::SHA256.hexdigest(PdfHelper::TINY_JPEG)
    jpx_digest = Digest::SHA256.hexdigest(jpx)
    assert_equal [ jpeg_digest, jpx_digest ].sort, files.keys.sort
    assert_equal PdfHelper::TINY_JPEG, files[jpeg_digest][:bytes]
    assert_equal "image/jpeg", files[jpeg_digest][:content_type]
  end

  test "skips images smaller than MIN_PIXELS" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    pages = [ { lines: [ "Figure 1: caption" ],
                images: [ image("Icon", width: 8, height: 8), image("Im1") ] } ]

    rows = with_pdf(pages) do |path|
      Image::Extractor.new(document, path).rows
    end

    assert_equal [ "Im1" ], rows.map { |row| row[:name] }
  end

  test "section is snapshotted after the full page scan and unnumbered headings reset" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    pages = [
      { lines: [ "1 Alpha Section", "Figure 1: overview diagram", "1.1 Beta Subsection" ], images: [ image("Im0") ] },
      { lines: [ "Gamma Unnumbered" ], images: [ image("Im0") ] }
    ]

    rows = with_pdf(pages) do |path|
      Image::Extractor.new(document, path).rows
    end

    assert_equal "Test Doc / 1 Alpha Section / 1.1 Beta Subsection", rows.first[:section_path]
    assert_equal "Test Doc / Gamma Unnumbered", rows.second[:section_path]
  end

  private

  def image(name, width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG)
    { name: name, width: width, height: height, filter: filter, data: data }
  end

  def compressed_pixels
    Zlib::Deflate.deflate("x" * 64)
  end
end
