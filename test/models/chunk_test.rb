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

  test "build_tsquery keeps unicode letters and drops single-letter elisions" do
    assert_equal "étanchéité", Chunk.build_tsquery([ "l'étanchéité" ])
    assert_equal "étanchéité & membranes", Chunk.build_tsquery([ "étanchéité membranes" ])
  end

  test "build_tsquery passes CJK through as letters" do
    assert_equal "防水 & 気密", Chunk.build_tsquery([ "防水 気密" ])
  end

  test "build_tsquery with punctuation-only terms returns nil" do
    assert_nil Chunk.build_tsquery([ "!!!", "…" ])
    assert_nil Chunk.build_tsquery([])
  end

  test "search_for stems french plurals into singular content" do
    document = Document.create!(title: "guide-fr", source_path: "/tmp/guide-fr.pdf", language: :fr)
    match = Chunk.create!(document:, page: 1, section_path: "guide-fr / Toiture", content: "la membrane d'étanchéité protège le bâtiment contre la pluie")

    results = Chunk.search_for([ "membranes d'étanchéité" ])

    assert_includes results.map(&:id), match.id
  end

  test "search_for matches accented content with unaccented query and vice versa" do
    accented = Document.create!(title: "accents", source_path: "/tmp/accents.pdf", language: :fr)
    accented_chunk = Chunk.create!(document: accented, page: 1, section_path: "accents / Air", content: "l'étanchéité à l'air des bâtiments est essentielle")
    plain = Document.create!(title: "plain", source_path: "/tmp/plain.pdf")
    plain_chunk = Chunk.create!(document: plain, page: 1, section_path: "plain / Air", content: "etancheite of the building shell matters")

    assert_includes Chunk.search_for([ "etancheite" ]).map(&:id), accented_chunk.id
    assert_includes Chunk.search_for([ "étanchéité" ]).map(&:id), plain_chunk.id
  end

  test "search_for narrows full-text hits by document language" do
    french = Document.create!(title: "fr-doc", source_path: "/tmp/fr-doc.pdf", language: :fr)
    french_chunk = Chunk.create!(document: french, page: 1, section_path: "fr-doc / Corps", content: "la membrane du toit")
    english = Document.create!(title: "en-doc", source_path: "/tmp/en-doc.pdf", language: :en)
    english_chunk = Chunk.create!(document: english, page: 1, section_path: "en-doc / Body", content: "the membrane of the roof")

    assert_equal [ french_chunk.id ], Chunk.search_for([ "membrane" ], languages: "fr").map(&:id)
    assert_equal [ english_chunk.id ], Chunk.search_for([ "membrane" ], languages: "en").map(&:id)
  end

  test "search_for applies the language filter before the trigram fallback" do
    french = Document.create!(title: "fr-fuzzy", source_path: "/tmp/fr-fuzzy.pdf", language: :fr)
    french_chunk = Chunk.create!(document: french, page: 1, section_path: "fr-fuzzy / Corps", content: "kubernetes")
    english = Document.create!(title: "en-fuzzy", source_path: "/tmp/en-fuzzy.pdf", language: :en)
    Chunk.create!(document: english, page: 1, section_path: "en-fuzzy / Body", content: "kubernetes")

    results = Chunk.search_for([ "kubernetees" ], languages: "fr")

    assert_equal [ french_chunk.id ], results.map(&:id)
  end
end
