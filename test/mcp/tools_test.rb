require "test_helper"

class ToolsTest < ActiveSupport::TestCase
  setup do
    Document.destroy_all
    @k8s = Document.create!(title: "k8s-guide", source_path: "/tmp/k8s-guide.pdf")
    Chunk.create!(document: @k8s, page: 1, section_path: "k8s-guide / Deployment", content: "kubernetes deployment rolling update strategy")
    Chunk.create!(document: @k8s, page: 2, section_path: "k8s-guide / Troubleshooting", content: "kubectl diagnose crash loops and failed pods")
    @food = Document.create!(title: "recipes", source_path: "/tmp/recipes.pdf")
    Chunk.create!(document: @food, page: 1, section_path: "recipes / Breakfast", content: "fluffy pancake recipe with buttermilk")
    @french = Document.create!(title: "guide-fr", source_path: "/tmp/guide-fr.pdf", language: :fr)
    Chunk.create!(document: @french, page: 1, section_path: "guide-fr / Toiture", content: "la toiture du bâtiment et les membranes")
  end

  test "search_pdfs returns matching chunks as JSON text" do
    response = SearchPdfsTool.call(terms: "kubernetes")
    payload = JSON.parse(response.content.first[:text])

    assert_equal 1, payload.length
    assert_equal "k8s-guide", payload.first["document"]
    assert_equal 1, payload.first["page"]
    assert_includes payload.first["content"], "kubernetes"
  end

  test "search_pdfs with junk terms asks for rephrase" do
    response = SearchPdfsTool.call(terms: "!!!")

    assert_includes response.content.first[:text], "rephrase"
  end

  test "list_toc groups sections per document" do
    payload = JSON.parse(ListTocTool.call.content.first[:text])

    assert_equal [ "guide-fr", "k8s-guide", "recipes" ], payload.map { |entry| entry["document"] }
    k8s = payload.find { |entry| entry["document"] == "k8s-guide" }
    assert_equal @k8s.id, k8s["id"]
    assert_equal [ "k8s-guide / Deployment", "k8s-guide / Troubleshooting" ], k8s["sections"].map { |s| s["path"] }
    assert_equal 1, k8s["sections"].first["chunks"]
  end

  test "list_toc carries a metadata summary per document" do
    payload = JSON.parse(ListTocTool.call.content.first[:text])

    payload.each do |entry|
      document = Document.find(entry["id"])
      assert_equal({ "title" => document.title, "author" => nil, "page_count" => nil }, entry["metadata"])
    end
  end

  test "read_section returns ordered rows" do
    payload = JSON.parse(ReadSectionTool.call(document_id: @k8s.id, section_prefix: "k8s-guide / Deployment").content.first[:text])

    assert_equal 1, payload.length
    assert_equal 1, payload.first["page"]
    assert_equal "k8s-guide / Deployment", payload.first["section"]
  end

  test "read_section with unknown document returns agent-friendly text" do
    payload = JSON.parse(ReadSectionTool.call(document_id: -1, section_prefix: "x").content.first[:text])

    assert_includes payload["error"], "not found"
  end

  test "search_pdfs rows carry kind and language" do
    payload = JSON.parse(SearchPdfsTool.call(terms: "kubernetes").content.first[:text])

    assert_equal "pdf", payload.first["kind"]
    assert_equal "en", payload.first["language"]
  end

  test "search_pdfs with lang narrows results" do
    payload = JSON.parse(SearchPdfsTool.call(terms: "membranes", lang: "fr").content.first[:text])

    assert_equal [ "guide-fr" ], payload.map { |row| row["document"] }.uniq
    assert_equal "fr", payload.first["language"]
  end

  test "search_pdfs with invalid lang returns a friendly error, not a protocol failure" do
    payload = JSON.parse(SearchPdfsTool.call(terms: "kubernetes", lang: "xx").content.first[:text])

    assert_includes payload["error"], "lang"
    assert_includes payload["hint"], "all languages"
  end

  test "list_toc carries language per document" do
    payload = JSON.parse(ListTocTool.call.content.first[:text])

    entry = payload.find { |document| document["id"] == @french.id }
    assert_equal "fr", entry["language"]
    assert_equal "en", payload.find { |document| document["id"] == @k8s.id }["language"]
  end
end
