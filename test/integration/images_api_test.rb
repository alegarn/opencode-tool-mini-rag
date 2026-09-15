require "test_helper"

class ImagesApiTest < ActionDispatch::IntegrationTest
  test "GET /images with terms returns ranked rows with context and file_url" do
    with_pdf(image_pages) do |path|
      document = Document.ingest!(path)

      get images_path, params: { terms: "deployment pipeline diagram" }

      assert_response :ok
      body = response.parsed_body
      assert_equal 1, body.length
      row = body.first
      assert_equal document.images.find_by(page: 1).id, row["id"]
      assert_equal document.id, row["document_id"]
      assert_equal document.title, row["document"]
      assert_equal 1, row["page"]
      assert_equal "#{document.title} / 1 Deployment", row["section"]
      assert_equal "Figure 1: Deployment pipeline diagram", row["caption"]
      assert_equal 200, row["width"]
      assert_equal 100, row["height"]
      assert_equal "image/jpeg", row["content_type"]
      assert_includes row["context_text"], "body text about deployment"
      assert row["file_url"].start_with?("/rails/active_storage/blobs/")
    end
  end

  test "GET /images with terms and k=1 returns at most one row" do
    with_pdf(captioned_pages) do |path|
      Document.ingest!(path)

      get images_path, params: { terms: "architecture diagram", k: 1 }

      assert_response :ok
      assert_equal 1, response.parsed_body.length
    end
  end

  test "GET /images without terms lists images in page order" do
    with_pdf(image_pages) do |path|
      document = Document.ingest!(path)

      get images_path

      assert_response :ok
      body = response.parsed_body
      assert_equal [ 1, 2, 3 ], body.pluck("page")
      flate_row = body.third
      assert_nil flate_row["caption"]
      assert_nil flate_row["content_type"]
      assert_nil flate_row["file_url"]
      assert_equal document.images.count, body.length
    end
  end

  test "GET /images with document_id scopes to one document" do
    with_pdf(image_pages) do |path|
      first = Document.ingest!(path)
      with_pdf([ { lines: [ "Figure 5: Deployment overview chart" ], images: [ { name: "Im9", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] } ]) do |other_path|
        Document.ingest!(other_path)

        get images_path, params: { document_id: first.id }

        assert_response :ok
        body = response.parsed_body
        assert body.all? { |row| row["document_id"] == first.id }
        assert_equal first.images.count, body.length
      end
    end
  end

  test "context_text joins same-page chunks in order" do
    long_body = (1..30).map { |i| "zebra marker at the start and plain lowercase filler number #{i} to push past one chunk window of a thousand characters total" }
    pages = [ { lines: [ "1 Long Section", *long_body, "yak marker at the very end" ],
                images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] } ]
    with_pdf(pages) do |path|
      Document.ingest!(path)

      get images_path

      context = response.parsed_body.first["context_text"]
      assert context.include?("\n---\n")
      assert context.index("zebra marker") < context.index("yak marker")
    end
  end

  test "GET /images/:id returns the row and file_url serves the bytes" do
    with_pdf(image_pages) do |path|
      document = Document.ingest!(path)
      image = document.images.find_by(page: 1)

      get image_path(image)

      assert_response :ok
      row = response.parsed_body
      assert_equal image.id, row["id"]
      file_url = row["file_url"]

      get file_url
      assert_response :redirect
      follow_redirect!

      assert_response :ok
      assert_equal "image/jpeg", @response.media_type
      assert_equal PdfHelper::TINY_JPEG, @response.body
    end
  end

  test "GET /images/:id with unknown id returns not_found" do
    get image_path(999999)

    assert_response :not_found
  end

  private

  def image_pages
    [
      { lines: [ "1 Deployment", "body text about deployment", "Figure 1: Deployment pipeline diagram" ],
        images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "second page without captions" ],
        images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "third page flate only" ],
        images: [ { name: "Im0", width: 150, height: 150, filter: "FlateDecode", data: Zlib::Deflate.deflate("x" * 48) } ] }
    ]
  end

  def captioned_pages
    [
      { lines: [ "Figure 1: Architecture diagram" ], images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "Figure 2: Architecture diagram again" ], images: [ { name: "Im1", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "Figure 3: Architecture diagram once more" ], images: [ { name: "Im2", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] }
    ]
  end
end
