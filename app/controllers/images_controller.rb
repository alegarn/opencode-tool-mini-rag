class ImagesController < ApplicationController
  def index
    permitted = params.permit(:terms, :document_id, :k)
    terms = permitted[:terms].presence
    document_id = permitted[:document_id].presence&.to_i
    k = [ [ permitted[:k].presence&.to_i || 6, 1 ].max, 20 ].min

    scope = terms ? Image.search_for(terms, k: k) : Image.order(:page, :name)
    scope = scope.where(document_id: document_id) if document_id
    images = scope.includes(:document, file_attachment: :blob)
    render json: images.map { |image| row(image) }
  end

  def show
    image = Image.includes(:document, file_attachment: :blob).find(params[:id])
    render json: row(image)
  end

  private

  def row(image)
    {
      id: image.id,
      document_id: image.document_id,
      document: image.document.title,
      page: image.page,
      section: image.section_path,
      caption: image.caption,
      width: image.width,
      height: image.height,
      content_type: image.content_type,
      file_url: file_url(image),
      context_text: image.context_text
    }
  end

  def file_url(image)
    Rails.application.routes.url_helpers.rails_blob_path(image.file, only_path: true) if image.file.attached?
  end
end
