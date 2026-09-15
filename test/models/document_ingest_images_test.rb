require "test_helper"

class DocumentIngestImagesTest < ActiveSupport::TestCase
  test "ingest! attaches one deduped blob per digest and skips byteless images" do
    with_isolated_storage do
      with_pdf(image_pages) do |path|
        document = Document.ingest!(path)

        assert_equal 3, document.images.count
        attached = document.images.select { |image| image.file.attached? }
        assert_equal [ 1, 2 ], attached.map(&:page)
        assert_equal 1, document.image_blobs.count
        assert_equal PdfHelper::TINY_JPEG, document.images.find_by(page: 1).file.blob.download
      end
    end
  end

  test "re-ingesting an unchanged file returns the same document without touching any row" do
    with_isolated_storage do
      with_pdf(image_pages) do |path|
        document = Document.ingest!(path)
        chunk_rows = document.chunks.order(:id).pluck(:id, :updated_at)
        image_rows = document.images.order(:id).pluck(:id, :updated_at)
        updated_at = document.updated_at
        blob_key = document.images.find_by(page: 1).file.blob.key

        reingested = Document.ingest!(path)

        assert_equal document.id, reingested.id
        assert_equal chunk_rows, reingested.chunks.order(:id).pluck(:id, :updated_at)
        assert_equal image_rows, reingested.images.order(:id).pluck(:id, :updated_at)
        assert_equal updated_at, reingested.updated_at
        assert_equal 3, reingested.images.count
        assert_equal blob_key, reingested.images.find_by(page: 1).file.blob.key
        assert File.exist?(ActiveStorage::Blob.service.path_for(blob_key))
      end
    end
  end

  test "re-ingest with a changed file fully replaces the document and purges replaced blobs" do
    with_isolated_storage do
      with_pdf(image_pages) do |path|
        document = Document.ingest!(path)
        old_key = document.images.find_by(page: 1).file.blob.key
        assert File.exist?(ActiveStorage::Blob.service.path_for(old_key))
        image_count = document.images.count

        File.binwrite(path, build_pdf(image_pages.map { |page| page.merge(lines: page[:lines] + [ "changed body text" ]) }))

        reingested = Document.ingest!(path)

        assert_not_equal document.id, reingested.id
        assert_nil Document.find_by(id: document.id)
        assert_equal image_count, reingested.images.count
        assert_equal 1, reingested.image_blobs.count
        assert_nil ActiveStorage::Blob.find_by(key: old_key)
        refute File.exist?(ActiveStorage::Blob.service.path_for(old_key))
      end
    end
  end

  test "failed re-ingest leaves the old document fully servable with zero orphan files" do
    with_isolated_storage do
      with_pdf(image_pages) do |path|
        document = Document.ingest!(path)
        image = document.images.find_by(page: 1)
        old_key = image.file.blob.key
        old_files = disk_files

        File.binwrite(path, build_pdf(image_pages.map { |page| page.merge(lines: page[:lines] + [ "changed body text" ]) }))
        failing_image_insert do
          assert_raises(ActiveRecord::RecordNotUnique) { Document.ingest!(path) }
        end

        document.reload
        assert document.images.exists?
        assert_equal PdfHelper::TINY_JPEG, image.reload.file.blob.download
        assert Rails.application.routes.url_helpers.rails_blob_path(image.file, only_path: true)

        keys = ActiveStorage::Blob.all.pluck(:key)
        files = disk_files
        assert_equal old_files.sort, files.sort
        assert_equal keys.sort, files.sort
      end
    end
  end

  test "destroy purges blobs and attachment rows" do
    with_isolated_storage do
      with_pdf(image_pages) do |path|
        document = Document.ingest!(path)
        key = document.images.find_by(page: 1).file.blob.key

        document.destroy

        assert_nil ActiveStorage::Blob.find_by(key: key)
        refute File.exist?(ActiveStorage::Blob.service.path_for(key))
        assert_equal 0, ActiveStorage::Attachment.where(record_type: "Image").count
        assert_equal 0, Image.count
      end
    end
  end

  private

  def with_isolated_storage
    Dir.mktmpdir do |root|
      previous_services = ActiveStorage::Blob.services
      previous_service = ActiveStorage::Blob.service
      begin
        ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new("isolated_test" => { "service" => "Disk", "root" => root })
        ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:isolated_test)
        yield
      ensure
        ActiveStorage::Blob.service = previous_service
        ActiveStorage::Blob.services = previous_services
      end
    end
  end

  # Forces the post-upload failure path (image insert blows up inside the
  # transaction, after blobs were already written to disk).
  def failing_image_insert
    Image.define_singleton_method(:insert_all!) { |*| raise ActiveRecord::RecordNotUnique, "duplicate image row" }
    yield
  ensure
    Image.singleton_class.remove_method(:insert_all!)
  end

  def disk_files
    Dir.glob(File.join(ActiveStorage::Blob.service.root, "**/*")).select { |file| File.file?(file) }.map { |file| File.basename(file) }
  end

  def image_pages
    [
      { lines: [ "1 Deployment", "body text about deployment", "Figure 1: Deployment pipeline diagram" ],
        images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "same jpeg again on another page" ],
        images: [ { name: "Im0", width: 200, height: 100, filter: "DCTDecode", data: PdfHelper::TINY_JPEG } ] },
      { lines: [ "flate images carry metadata only" ],
        images: [ { name: "Im0", width: 150, height: 150, filter: "FlateDecode", data: Zlib::Deflate.deflate("x" * 48) } ] }
    ]
  end
end
