class DocumentsController < ApplicationController
  def create
    path = params.expect(:path)
    unless File.exist?(path) && path.end_with?(".pdf")
      render json: { error: "path must be an existing .pdf file" }, status: :bad_request
      return
    end

    existing_id = Document.where(source_path: path).pick(:id)
    document = Document.ingest!(path)
    render json: document.toc, status: existing_id == document.id ? :ok : :created
  end

  def index
    render json: Document.toc
  end

  def show
    render json: Document.find(params[:id]).toc
  end
end
