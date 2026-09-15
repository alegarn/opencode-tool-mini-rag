class Document < ApplicationRecord
  has_many :chunks, dependent: :delete_all
  has_many :images, dependent: :delete_all
  validates :title, :source_path, presence: true

  METADATA_KEYS = %i[Title Author Subject Keywords Creator Producer CreationDate ModDate].freeze
  private_constant :METADATA_KEYS

  # Bang ingest with an explicit blob lifecycle: disk writes (blob upload,
  # purge) NEVER happen inside the DB transaction because a rollback cannot
  # undo File.delete.
  #
  # Idempotent re-ingest: the SHA256 digest is computed before any mutation;
  # when a document already exists at this path with the same digest the file
  # is unchanged and the existing document is returned untouched (idempotent
  # POST semantics — the controller answers 200, not 201).
  #
  # 1. extract rows + bytes outside the transaction, then upload one blob per
  #    unique digest (deduped via the in-run memo — never a global Blob.find_by,
  #    cross-document blob sharing would make purge-on-replace destroy another
  #    document's file)
  # 2. transaction: raw-delete the old document, create the new one, bulk
  #    insert chunks, images, and attachment rows (insert_all skips ActiveStorage
  #    callbacks — intended: no mirror/analyze jobs, which would need a
  #    forbidden image gem)
  # 3. after commit: purge the old document's blobs
  # 4. on failure after upload: purge the uploaded (never-attached) blobs and
  #    re-raise
  def self.ingest!(path)
    digest = Digest::SHA256.file(path).hexdigest
    existing = find_by(source_path: path)
    return existing if existing&.digest == digest

    uploaded = {}
    document = nil
    begin
      reader = PDF::Reader.new(path)
      attributes = {
        title: reader.info[:Title].presence || File.basename(path, ".pdf"),
        source_path: path,
        digest: digest,
        metadata: metadata_from(reader.info),
        page_count: reader.page_count,
        pdf_version: reader.pdf_version.to_s
      }
      draft = new(**attributes)
      chunk_rows = Chunk::Extractor.new(draft, path).rows
      extractor = Image::Extractor.new(draft, path)
      image_rows = extractor.rows
      uploaded = upload_blobs(extractor.files)

      old_blobs = existing ? existing.image_blobs.to_a : []
      document = transaction do
        existing&.delete_rows
        created = create!(**attributes)
        now = Time.current
        Chunk.insert_all!(chunk_rows.map { |row| row.merge(document_id: created.id, created_at: now, updated_at: now) })
        attach_images!(image_rows, uploaded, created, now)
        created
      end

      old_blobs.each(&:purge)
      document
    rescue StandardError
      uploaded.each_value(&:purge) if document.nil?
      raise
    end
  end

  # Shared ToC shaping seam (SRP): DocumentsController#index and ListTocTool
  # both render exactly this payload — one query, two adapters. Entries carry
  # a metadata summary (title, author, page_count) alongside the sections.
  def self.toc
    rows = joins(:chunks)
           .select("documents.id, documents.title, documents.metadata, documents.page_count, chunks.section_path, count(*) AS chunk_count")
           .group("documents.id", "documents.title", "documents.metadata", "documents.page_count", "chunks.section_path")
           .order("documents.title, chunks.section_path")
    rows.each_with_object([]) do |row, documents|
      documents << { id: row.id, document: row.title, metadata: metadata_summary(row), sections: [] } if documents.last&.fetch(:id) != row.id
      documents.last[:sections] << { path: row.section_path, chunks: row.chunk_count }
    end
  end

  # Full per-document payload for #show and idempotent #create responses.
  def toc
    {
      id: id,
      title: title,
      metadata: metadata,
      page_count: page_count,
      pdf_version: pdf_version,
      chunks: chunks.count,
      images: images.count,
      sections: sections
    }
  end

  # Purges this document's image blobs after destruction. Disk deletes must
  # not run inside an open transaction — do not call from within one
  # (Document.ingest! uses #delete_rows inside its transaction instead).
  def destroy
    blobs = image_blobs.to_a
    ActiveStorage::Attachment.where(record_type: "Image", record_id: images.select(:id)).delete_all
    destroyed = super
    blobs.each(&:purge) if destroyed
    destroyed
  end

  def image_blobs
    ActiveStorage::Blob.where(id: ActiveStorage::Attachment.where(record_type: "Image", record_id: images.select(:id)).select(:blob_id))
  end

  # Row-level delete without blob purge — the caller owns the blob lifecycle
  # (Document.ingest! purges after commit, #destroy purges immediately).
  def delete_rows
    ActiveStorage::Attachment.where(record_type: "Image", record_id: images.select(:id)).delete_all
    images.delete_all
    chunks.delete_all
    self.class.delete(id)
  end

  BLOB_EXTENSIONS = { "image/jpeg" => ".jpg", "image/jp2" => ".jp2" }.freeze
  private_constant :BLOB_EXTENSIONS

  private

  def sections
    chunks.group(:section_path).count.map { |path, count| { path:, chunks: count } }
  end

  private_class_method def self.metadata_from(info)
    METADATA_KEYS.each_with_object({}) do |key, metadata|
      metadata[key] = info[key] unless info[key].nil?
    end
  end

  private_class_method def self.metadata_summary(row)
    { title: row.title, author: row.metadata&.dig("Author"), page_count: row.page_count }
  end

  private_class_method def self.upload_blobs(files)
    files.each_with_object({}) do |(digest, file), uploaded|
      uploaded[digest] ||= ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(file[:bytes]),
        filename: "#{digest}#{BLOB_EXTENSIONS.fetch(file[:content_type], "")}",
        content_type: file[:content_type]
      )
    end
  end

  private_class_method def self.attach_images!(image_rows, uploaded, document, now)
    return if image_rows.empty?

    image_ids = Image.insert_all!(
      image_rows.map { |row| row.merge(document_id: document.id, created_at: now, updated_at: now) },
      returning: [ :id ]
    ).map { |record| record["id"] }
    attachments = image_rows.zip(image_ids).filter_map do |row, image_id|
      blob = uploaded[row[:digest]]
      { name: "file", record_type: "Image", record_id: image_id, blob_id: blob.id, created_at: now } if blob
    end
    ActiveStorage::Attachment.insert_all!(attachments) if attachments.any?
  end
end
