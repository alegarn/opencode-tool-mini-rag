class ChunksController < ApplicationController
  def index
    terms = Array(params[:terms]).flat_map { |term| term.to_s.split("|") }
    k = [ [ params.fetch(:k, 6).to_i, 1 ].max, 20 ].min
    if Chunk.build_tsquery(terms).nil?
      render json: { error: "terms must contain at least one word" }, status: :bad_request
      return
    end

    chunks = Chunk.search_for(terms, k: k).includes(:document)
    render json: chunks.map { |chunk| { document: chunk.document.title, document_id: chunk.document_id, page: chunk.page, section: chunk.section_path, content: chunk.content } }
  end
end
