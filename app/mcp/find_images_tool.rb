class FindImagesTool < MCP::Tool
  tool_name "find_images"
  description <<~DESCRIPTION
    Find embedded figures/images by caption or section vocabulary. Returns legend (caption), section, page, dimensions, associated same-page text, and a file URL. Use SHORT keyword terms (2-4 words per group, not full questions — trigram similarity on captions scores phrases low). Rephrase using figure-naming words (Figure, diagram, chart, screenshot) and likely section names; retry differently when empty.
    TRANSLATE-THEN-SEARCH: the corpus holds more than one language (check `list_toc` `language` fields; currently en, fr) — translate the keywords into EACH corpus language and pass them in ONE call, e.g. terms "sealing detail junction | détail étanchéité jonction". Do not run one search per language; when a language's figures are missing or weak, rephrase that language's vocabulary and retry.
  DESCRIPTION
  input_schema(
    properties: {
      terms: { type: "string" },
      k: { type: "integer", default: 6 }
    },
    required: [ "terms" ]
  )

  class << self
    def call(terms:, k: 6)
      return rephrase_response if terms.to_s.scan(/[a-zA-Z0-9]+/).empty?

      images = Image.search_for(terms, k: k).includes(:document, file_attachment: :blob)
      payload = images.map { |image| row(image) }
      MCP::Tool::Response.new([ { type: "text", text: payload.to_json } ])
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

    def rephrase_response
      hint = { error: "terms contains no searchable words", hint: "retry with 2-4 figure-naming keywords (e.g. 'diagram deployment') and likely section names" }
      MCP::Tool::Response.new([ { type: "text", text: hint.to_json } ])
    end
  end
end
