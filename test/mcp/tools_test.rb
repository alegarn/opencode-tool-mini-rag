require "test_helper"

class ToolsTest < ActiveSupport::TestCase
  setup do
    Document.destroy_all
    @k8s = Document.create!(title: "k8s-guide", source_path: "/tmp/k8s-guide.pdf")
    Chunk.create!(document: @k8s, page: 1, section_path: "k8s-guide / Deployment", content: "kubernetes deployment rolling update strategy")
    Chunk.create!(document: @k8s, page: 2, section_path: "k8s-guide / Troubleshooting", content: "kubectl diagnose crash loops and failed pods")
    @food = Document.create!(title: "recipes", source_path: "/tmp/recipes.pdf")
    Chunk.create!(document: @food, page: 1, section_path: "recipes / Breakfast", content: "fluffy pancake recipe with buttermilk")
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

    assert_equal [ "k8s-guide", "recipes" ], payload.map { |entry| entry["document"] }
    k8s = payload.first
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
end
