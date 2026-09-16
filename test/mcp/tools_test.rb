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

  test "search_pdfs description carries the TRANSLATE-THEN-SEARCH contract" do
    description = SearchPdfsTool.description

    assert_includes description, "TRANSLATE-THEN-SEARCH"
    assert_includes description, "list_toc"
    assert_includes description, "window sealing tape junction | calfeutrage fenêtre ruban jonction"
    assert_includes description, "Do not run one search per language"
    assert description.length < 1200, "descriptions ship in every tools/list — keep them tight"
  end

  test "find_images description carries the TRANSLATE-THEN-SEARCH contract" do
    description = FindImagesTool.description

    assert_includes description, "TRANSLATE-THEN-SEARCH"
    assert_includes description, "list_toc"
    assert_includes description, "sealing detail junction | détail étanchéité jonction"
    assert_includes description, "Do not run one search per language"
    assert description.length < 1200, "descriptions ship in every tools/list — keep them tight"
  end

  test "search_pdfs translated group reaches the other language in one call" do
    Chunk.create!(document: @french, page: 2, section_path: "guide-fr / Calfeutrage", content: "calfeutrage des fenêtres avec des rubans étanches")

    alone = JSON.parse(SearchPdfsTool.call(terms: "caulking").content.first[:text])
    assert_empty alone, "monolingual caulking must not leak into french stems"

    translated = JSON.parse(SearchPdfsTool.call(terms: "caulking|calfeutrage").content.first[:text])
    assert translated.any? { |row| row["content"].match?(/calfeutr/i) && row["language"] == "fr" }
  end

  test "search_pdfs terms grammar ANDs words inside a group, ORs across groups" do
    both = JSON.parse(SearchPdfsTool.call(terms: "kubernetes deployment").content.first[:text])
    assert both.any? { |row| row["content"].include?("kubernetes") }

    mixed = JSON.parse(SearchPdfsTool.call(terms: "kubernetes pancake").content.first[:text])
    assert_empty mixed, "flat-OR parsing regression: words from different chunks must not satisfy one group"
  end
end
