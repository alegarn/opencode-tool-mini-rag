require "test_helper"

class DocumentsApiTest < ActionDispatch::IntegrationTest
  test "POST /documents ingests a pdf and returns table of contents" do
    with_pdf([ [ "Introduction", "lowercase body text here" ], [ "3.2 Methods", "more lowercase body text" ] ]) do |path|
      post documents_path, params: { path: }, as: :json

      assert_response :created
      body = response.parsed_body
      document = Document.find(body["id"])

      assert_equal document.title, body["title"]
      sections = body["sections"].map { |section| [ section["path"], section["chunks"] ] }.to_h
      assert_equal document.chunks.group(:section_path).count, sections
    end
  end

  test "POST /documents with nonexistent path returns bad_request" do
    post documents_path, params: { path: "/nonexistent/file.pdf" }, as: :json

    assert_response :bad_request
    assert response.parsed_body.key?("error")
  end

  test "POST /documents with unchanged file is idempotent" do
    with_pdf([ [ "Introduction", "lowercase body text here" ] ]) do |path|
      post documents_path, params: { path: }, as: :json
      assert_response :created
      id = response.parsed_body["id"]
      chunk_rows = Chunk.order(:id).pluck(:id, :updated_at)
      document_updated_at = Document.find(id).updated_at

      post documents_path, params: { path: }, as: :json

      assert_response :ok
      assert_equal id, response.parsed_body["id"]
      assert_equal chunk_rows, Chunk.order(:id).pluck(:id, :updated_at)
      assert_equal document_updated_at, Document.find(id).updated_at
    end
  end

  test "GET /documents/:id returns metadata, toc, and counts" do
    info = { Title: "Custom Title", Author: "Jane Doe" }
    with_pdf([ [ "Introduction", "lowercase body text here" ] ], info:) do |path|
      post documents_path, params: { path: }, as: :json
      id = response.parsed_body["id"]

      get document_path(id)

      assert_response :ok
      body = response.parsed_body
      assert_equal id, body["id"]
      assert_equal "Custom Title", body["title"]
      assert_equal({ "Title" => "Custom Title", "Author" => "Jane Doe" }, body["metadata"])
      assert_equal 1, body["page_count"]
      assert_equal "1.4", body["pdf_version"]
      assert_equal 1, body["chunks"]
      assert_equal 0, body["images"]
      assert_equal [ [ "Custom Title / Introduction", 1 ] ], body["sections"].map { |section| [ section["path"], section["chunks"] ] }
    end
  end

  test "GET /documents/:id with unknown id returns not_found" do
    get document_path(-1)

    assert_response :not_found
  end

  test "GET /documents carries a metadata summary per entry" do
    info = { Title: "Custom Title", Author: "Jane Doe" }
    with_pdf([ [ "Introduction", "lowercase body text here" ] ], info:) do |path|
      post documents_path, params: { path: }, as: :json
      id = response.parsed_body["id"]

      get documents_path

      assert_response :ok
      entry = response.parsed_body.find { |document| document["id"] == id }
      assert_equal "Custom Title", entry["document"]
      assert_equal({ "title" => "Custom Title", "author" => "Jane Doe", "page_count" => 1 }, entry["metadata"])
      assert entry["sections"].is_a?(Array)
    end
  end

  test "POST /documents with non-pdf file returns bad_request" do
    Tempfile.create([ "test", ".txt" ]) do |file|
      file.write("not a pdf")
      file.flush
      post documents_path, params: { path: file.path }, as: :json
    end

    assert_response :bad_request
    assert response.parsed_body.key?("error")
  end

  test "document payloads carry language from detection at ingest" do
    with_pdf([ [ "Intro", "le guide présente les membranes de toiture et la pose est une étape du bâtiment" ] ]) do |path|
      post documents_path, params: { path: }, as: :json
      assert_equal "fr", response.parsed_body["language"]

      get documents_path
      entry = response.parsed_body.find { |document| document["id"] == response.parsed_body.first["id"] }
      assert_equal "fr", entry["language"]

      get document_path(entry["id"])
      assert_equal "fr", response.parsed_body["language"]
    end
  end
end
