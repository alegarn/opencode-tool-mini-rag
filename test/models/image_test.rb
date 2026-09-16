require "test_helper"

class ImageTest < ActiveSupport::TestCase
  test "search_for matches captions via trigram similarity and orders by score" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    match = Image.create!(document: document, page: 1, section_path: "guide / Deployment", name: "Im0", caption: "Cluster deployment diagram", digest: "d1")
    Image.create!(document: document, page: 2, section_path: "guide / Breakfast", name: "Im1", caption: "Pancake batter illustration", digest: "d2")

    results = Image.search_for("deployment diagram")

    assert_equal [ match.id ], results.map(&:id)
  end

  test "search_for matches nil captions through the section path" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    match = Image.create!(document: document, page: 1, section_path: "guide / Troubleshooting", name: "Im0", caption: nil, digest: "d1")

    results = Image.search_for("troubleshooting chart")

    assert_equal [ match.id ], results.map(&:id)
  end

  test "search_for ORs pipe groups: one language's group cannot dilute the other's match" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    english = Image.create!(document: document, page: 1, section_path: "guide / Deployment", name: "Im0", caption: "Cluster deployment diagram", digest: "d1")
    french = Image.create!(document: document, page: 2, section_path: "guide / Déploiement", name: "Im1", caption: "Diagramme de déploiement du cluster", digest: "d2")

    results = Image.search_for("deployment diagram | diagramme déploiement")

    assert_equal [ english.id, french.id ].sort, results.map(&:id).sort
  end

  test "search_for ignores junk groups and keeps strong single-group matches" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    match = Image.create!(document: document, page: 1, section_path: "guide / Deployment", name: "Im0", caption: "Cluster deployment diagram", digest: "d1")

    results = Image.search_for("deployment diagram | !!! ...")

    assert_equal [ match.id ], results.map(&:id)
  end

  test "search_for with only junk groups returns nothing" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    Image.create!(document: document, page: 1, section_path: "guide / Deployment", name: "Im0", caption: "Cluster deployment diagram", digest: "d1")

    assert_empty Image.search_for("!!! | ...")
  end

  test "context_text joins same-page chunks in id order" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    Chunk.create!(document: document, page: 1, section_path: "guide / A", content: "first same page chunk")
    Chunk.create!(document: document, page: 1, section_path: "guide / A", content: "second same page chunk")
    Chunk.create!(document: document, page: 2, section_path: "guide / B", content: "other page chunk")
    image = Image.create!(document: document, page: 1, section_path: "guide / A", name: "Im0", digest: "d1")

    assert_equal "first same page chunk\n---\nsecond same page chunk", image.context_text
  end
end
