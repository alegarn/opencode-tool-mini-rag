class Documents::SectionsController < ApplicationController
  def index
    prefix = params.expect(:prefix)
    chunks = Document.find(params[:document_id]).chunks.in_section(prefix).in_reading_order
    render json: chunks.pluck(:page, :section_path, :content).map { |page, section, content| { page:, section:, content: } }
  end
end
