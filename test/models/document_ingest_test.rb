require "test_helper"

class DocumentIngestTest < ActiveSupport::TestCase
  test "ingest! maps the Info dict to title, pruned metadata, page_count, and pdf_version" do
    pages = [ [ "1 Overview", "plain body text about the guide" ], [ "1.1 Scope", "more plain body text" ] ]
    info = { Title: "Xubuntu Guide", Author: "Jane Doe", Keywords: "docs, setup", Creator: "writer", Producer: "pdfkit",
             Subject: nil, Custom: "dropped" }
    with_pdf(pages, info:) do |path|
      document = Document.ingest!(path)

      assert_equal "Xubuntu Guide", document.title
      assert_equal({ "Title" => "Xubuntu Guide", "Author" => "Jane Doe", "Keywords" => "docs, setup", "Creator" => "writer", "Producer" => "pdfkit" }, document.metadata)
      assert_equal 2, document.page_count
      assert_equal "1.4", document.pdf_version
      assert_match(/\A[0-9a-f]{64}\z/, document.digest)
    end
  end

  test "ingest! falls back to the filename when the Info dict has no title" do
    with_pdf([ [ "1 Overview", "plain body text" ] ], info: { Author: "Jane Doe" }) do |path|
      document = Document.ingest!(path)

      assert_equal File.basename(path, ".pdf"), document.title
      assert_equal({ "Author" => "Jane Doe" }, document.metadata)
    end
  end
end
