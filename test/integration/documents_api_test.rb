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

  test "POST /documents with non-pdf file returns bad_request" do
    Tempfile.create([ "test", ".txt" ]) do |file|
      file.write("not a pdf")
      file.flush
      post documents_path, params: { path: file.path }, as: :json
    end

    assert_response :bad_request
    assert response.parsed_body.key?("error")
  end
end
