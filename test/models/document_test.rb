require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "ingest! creates document and chunks" do
    with_pdf([ [ "Introduction", "some lowercase body text" ] ]) do |path|
      document = Document.ingest!(path)

      assert_equal File.basename(path, ".pdf"), document.title
      assert_equal path, document.source_path
      assert document.chunks.exists?
      assert document.chunks.all? { |chunk| chunk.section_path.start_with?("#{document.title} /") }
    end
  end

  test "ingest! is idempotent for the same source_path" do
    with_pdf([ [ "Introduction", "some lowercase body text" ] ]) do |path|
      first = Document.ingest!(path)
      first_count = first.chunks.count

      second = Document.ingest!(path)

      assert_equal 1, Document.count
      assert_equal first_count, second.chunks.count
    end
  end
end
