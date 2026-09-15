class DocumentsController < ApplicationController
  def create
    path = params.expect(:path)
    unless File.exist?(path) && path.end_with?(".pdf")
      render json: { error: "path must be an existing .pdf file" }, status: :bad_request
      return
    end

    document = Document.ingest!(path)
    render json: toc(document), status: :created
  end

  def index
    render json: tocs
  end

  private

  def tocs
    rows = Chunk.joins(:document)
                .select("documents.id, documents.title, chunks.section_path, count(*) AS chunks")
                .group("documents.id", "documents.title", "chunks.section_path")
                .order("documents.title, chunks.section_path")
    rows.each_with_object([]) do |row, documents|
      documents << { id: row.id, document: row.title, sections: [] } if documents.last&.fetch(:id) != row.id
      documents.last[:sections] << { path: row.section_path, chunks: row.chunks }
    end
  end

  def toc(document)
    sections = document.chunks.group(:section_path).count.map { |path, count| { path:, chunks: count } }
    { id: document.id, title: document.title, sections: }
  end
end
