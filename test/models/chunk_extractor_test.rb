require "test_helper"

class Chunk::ExtractorTest < ActiveSupport::TestCase
  test "rows carry document_id, page, and section_path from heading stack" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    body = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur excepteur sint occaecat cupidatat non proident sunt in culpa qui officia deserunt mollit anim id est laborum"
    pages = [
      [ "Introduction", body, body ],
      [ "3.2 Methods", body, body ],
      [ body ]
    ]

    rows = with_pdf(pages) do |path|
      Chunk::Extractor.new(document, path).rows
    end

    assert rows.all? { |row| row[:document_id] == document.id }
    assert rows.all? { |row| row.key?(:content) }

    page_one = rows.select { |row| row[:page] == 1 }
    page_two = rows.select { |row| row[:page] == 2 }
    page_three = rows.select { |row| row[:page] == 3 }

    assert page_one.all? { |row| row[:section_path] == "Test Doc / Introduction" }
    assert page_two.all? { |row| row[:section_path] == "Test Doc / Introduction / 3.2 Methods" }
    assert page_three.all? { |row| row[:section_path] == "Test Doc / Introduction / 3.2 Methods" }
  end

  test "unnumbered heading resets the stack" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    pages = [
      [ "1 First", body_line ],
      [ "1.1 Nested", body_line ],
      [ "Second", body_line ]
    ]

    rows = with_pdf(pages) do |path|
      Chunk::Extractor.new(document, path).rows
    end

    assert_equal [ "Test Doc / 1 First", "Test Doc / 1 First / 1.1 Nested", "Test Doc / Second" ], rows.map { |row| row[:section_path] }.uniq
  end

  test "long page content is chunked with overlap" do
    document = Document.create!(title: "Test Doc", source_path: "/tmp/test_doc.pdf")
    long_lines = (1..30).map { |i| "word group number #{i} with plenty of plain lowercase text padding to fill the page across multiple chunk windows of a thousand characters total" }
    pages = [ [ "Heading Only Title" ], long_lines ]

    rows = with_pdf(pages) do |path|
      Chunk::Extractor.new(document, path).rows
    end

    chunks = rows.select { |row| row[:page] == 2 }.map { |row| row[:content] }
    assert chunks.size >= 2
    assert chunks.all? { |content| content.length <= Chunk::Extractor::SIZE }
    assert_equal chunks.first[Chunk::Extractor::SIZE - Chunk::Extractor::OVERLAP, Chunk::Extractor::OVERLAP], chunks.second[0, Chunk::Extractor::OVERLAP]
  end

  private

  def body_line
    "plain lowercase body text that is clearly not a heading at all"
  end
end
