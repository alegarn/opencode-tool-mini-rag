require "test_helper"

class ChunkTest < ActiveSupport::TestCase
  test "search_for falls back to trigram similarity when tsquery misses" do
    document = Document.create!(title: "glossary", source_path: "/tmp/glossary.pdf")
    match = Chunk.create!(document:, page: 1, section_path: "glossary / Terms", content: "kubernetes")
    Chunk.create!(document:, page: 2, section_path: "glossary / Other", content: "pancake recipe with buttermilk")

    results = Chunk.search_for([ "kubernetees" ])

    assert_equal [ match.id ], results.map(&:id)
  end

  test "search_for ranks section match above body-only match" do
    document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    body_only = Chunk.create!(document:, page: 1, section_path: "guide / Intro", content: "notes about deployment details")
    section_match = Chunk.create!(document:, page: 2, section_path: "guide / Deployment", content: "rolling update strategy overview")

    results = Chunk.search_for([ "deployment" ])

    assert_equal [ section_match.id, body_only.id ], results.map(&:id)
  end
end
