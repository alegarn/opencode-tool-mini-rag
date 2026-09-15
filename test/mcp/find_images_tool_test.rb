require "test_helper"

class FindImagesToolTest < ActiveSupport::TestCase
  setup do
    Document.destroy_all
    @document = Document.create!(title: "guide", source_path: "/tmp/guide.pdf")
    Chunk.create!(document: @document, page: 1, section_path: "guide / Deployment", content: "same page text about deployment steps")
    @image = Image.create!(document: @document, page: 1, section_path: "guide / Deployment", name: "Im0",
                           caption: "Deployment pipeline diagram", content_type: "image/jpeg", width: 200, height: 100, digest: "d1")
    @image.file.attach(io: StringIO.new("jpeg-bytes"), filename: "d1.jpg", content_type: "image/jpeg")
  end

  test "find_images returns rows with caption, context_text, and file_url" do
    payload = JSON.parse(FindImagesTool.call(terms: "deployment diagram").content.first[:text])

    assert_equal 1, payload.length
    row = payload.first
    assert_equal @image.id, row["id"]
    assert_equal @document.id, row["document_id"]
    assert_equal "guide", row["document"]
    assert_equal 1, row["page"]
    assert_equal "guide / Deployment", row["section"]
    assert_equal "Deployment pipeline diagram", row["caption"]
    assert_equal "image/jpeg", row["content_type"]
    assert_equal 200, row["width"]
    assert_equal 100, row["height"]
    assert_includes row["context_text"], "same page text about deployment steps"
    assert row["file_url"].start_with?("/rails/active_storage/blobs/")
  end

  test "find_images with junk terms returns friendly retry text" do
    text = FindImagesTool.call(terms: "!!!").content.first[:text]

    assert_includes text, "retry"
  end

  test "find_images with no hits returns empty array" do
    payload = JSON.parse(FindImagesTool.call(terms: "kubernetes").content.first[:text])

    assert_equal [], payload
  end
end
