class Documents::SectionsController < ApplicationController
  def index
    prefix = params.expect(:prefix)
    chunks = Document.find(params[:document_id]).chunks.in_section(prefix).order(:page)
    render json: chunks.pluck(:page, :section_path, :content).map { |page, section, content| { page:, section:, content: } }
  end
end
