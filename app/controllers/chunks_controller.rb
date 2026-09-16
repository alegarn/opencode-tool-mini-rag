class ChunksController < ApplicationController
  def index
    terms = Array(params[:terms]).flat_map { |term| term.to_s.split("|") }
    k = [ [ params.fetch(:k, 6).to_i, 1 ].max, 20 ].min
    lang = params[:lang].presence
    if lang && !%w[en fr].include?(lang)
      render json: { error: "lang must be 'en' or 'fr'" }, status: :bad_request
      return
    end
    if Chunk.build_tsquery(terms).nil?
      render json: { error: "terms must contain at least one word" }, status: :bad_request
      return
    end

    chunks = Chunk.search_for(terms, k: k, languages: lang).includes(:document)
    render json: chunks.map { |chunk| row_payload(chunk) }
  end

  private

  # kind is a literal until documents.kind lands with sub-feature H (H1f
  # swaps it for chunk.document.kind when the web corpus exists).
  def row_payload(chunk)
    {
      document: chunk.document.title,
      document_id: chunk.document_id,
      page: chunk.page,
      section: chunk.section_path,
      content: chunk.content,
      kind: "pdf",
      language: chunk.document.language
    }
  end
end
