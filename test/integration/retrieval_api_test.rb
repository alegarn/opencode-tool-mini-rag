require "test_helper"

class RetrievalApiTest < ActionDispatch::IntegrationTest
  test "GET /chunks returns ranked matches for pipe-joined terms" do
    with_pdf([ [ "Introduction", "deployment guide for kubernetes clusters" ], [ "3.2 Methods", "recipe for pancakes" ] ]) do |path|
      document = Document.ingest!(path)

      get chunks_path, params: { terms: "kubernetes|deploy" }

      assert_response :ok
      body = response.parsed_body
      assert_equal 1, body.length
      assert_equal document.id, body.first["document_id"]
      assert_equal document.title, body.first["document"]
      assert_includes body.first["section"], document.title
      assert_includes body.first["content"], "kubernetes"
    end
  end

  test "GET /chunks with terms array and k clamp" do
    with_pdf([ [ "Intro", "kubernetes one kubernetes two kubernetes three" ], [ "2 Next", "kubernetes four" ], [ "3 Last", "kubernetes five" ] ]) do |path|
      Document.ingest!(path)

      get chunks_path, params: { terms: [ "kubernetes" ], k: 2 }

      assert_response :ok
      assert_equal 2, response.parsed_body.length
    end
  end

  test "GET /chunks without usable terms returns bad_request" do
    get chunks_path, params: { terms: "!!!" }

    assert_response :bad_request
    assert response.parsed_body.key?("error")
  end

  test "GET /chunks with empty terms returns bad_request" do
    get chunks_path, params: { terms: "" }

    assert_response :bad_request
  end

  test "GET /documents returns table of contents grouped by document" do
    with_pdf([ [ "Alpha", "first page content about kubernetes" ], [ "second page without heading" ] ]) do |path|
      first = Document.ingest!(path)
      with_pdf([ [ "2.1 Beta", "recipe for pancakes" ] ]) do |other_path|
        second = Document.ingest!(other_path)

        get documents_path

        assert_response :ok
        body = response.parsed_body
        assert_equal 2, body.length
        entry = body.find { |document| document["id"] == first.id }
        assert_equal first.title, entry["document"]
        sections = entry["sections"]
        assert_equal first.chunks.distinct.count(:section_path), sections.length
        assert_equal sections.map { |section| section["path"] }.sort, sections.map { |section| section["path"] }
        assert_equal first.chunks.count, sections.sum { |section| section["chunks"] }
        assert body.any? { |document| document["id"] == second.id }
      end
    end
  end

  test "GET /documents with no documents returns empty array" do
    Document.destroy_all

    get documents_path

    assert_response :ok
    assert_equal [], response.parsed_body
  end

  test "GET /documents/:id/sections returns chunks of one section ordered by page" do
    with_pdf([ [ "Alpha", "first page content about kubernetes" ], [ "second page without heading" ], [ "2 Beta", "other section content" ] ]) do |path|
      document = Document.ingest!(path)

      get document_sections_path(document), params: { prefix: "#{document.title} / Alpha" }

      assert_response :ok
      body = response.parsed_body
      assert_equal 2, body.length
      assert_equal [ 1, 2 ], body.pluck("page")
      assert body.all? { |chunk| chunk["section"] == "#{document.title} / Alpha" }
    end
  end

  test "GET /documents/:id/sections escapes percent literals in prefix" do
    with_pdf([ [ "2 Methods", "recipe for pancakes" ] ]) do |path|
      document = Document.ingest!(path)

      get document_sections_path(document), params: { prefix: "#{document.title} / 2 M%e" }

      assert_response :ok
      assert_equal [], response.parsed_body
    end
  end

  test "GET /documents/:id/sections without prefix returns bad_request" do
    with_pdf([ [ "Alpha", "content" ] ]) do |path|
      document = Document.ingest!(path)

      get document_sections_path(document)

      assert_response :bad_request
    end
  end

  test "GET /documents/:id/sections with unknown document returns not_found" do
    get document_sections_path(999999), params: { prefix: "x" }

    assert_response :not_found
  end
end
