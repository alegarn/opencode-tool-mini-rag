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
    with_pdf([ [ "1 Overview", "plain body text about the guide" ] ], info: { Author: "Jane Doe" }) do |path|
      document = Document.ingest!(path)

      assert_equal File.basename(path, ".pdf"), document.title
      assert_equal({ "Author" => "Jane Doe" }, document.metadata)
    end
  end

  test "ingest! scrubs invalid UTF-8 Info titles instead of raising on blank?" do
    broken_title = [ 0xFE, 0xFF, 0x00, 0x47, 0xD8, 0x00, 0x41 ].pack("C*")
    with_pdf([ [ "Intro", "plain body text about the guide" ] ], info: { Title: broken_title }) do |path|
      document = Document.ingest!(path)

      assert document.title.valid_encoding?
      assert document.title.start_with?("G")
      assert document.metadata["Title"].valid_encoding?
    end
  end

  test "ingest! detects french content and stores it as language" do
    with_pdf([ [ "Intro", "le guide présente les membranes de toiture et la pose est une étape du bâtiment" ] ]) do |path|
      document = Document.ingest!(path)

      assert_equal "fr", document.language
      assert document.fr?
    end
  end

  test "ingest! detects english content and stores it as language" do
    with_pdf([ [ "Intro", "the guide covers membrane roofing and this is one of the steps for the crew" ] ]) do |path|
      document = Document.ingest!(path)

      assert_equal "en", document.language
      assert document.en?
    end
  end
end
