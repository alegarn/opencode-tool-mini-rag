class SearchPdfsTool < MCP::Tool
  tool_name "search_pdfs"
  description <<~DESCRIPTION
    Full-text search over ingested PDFs in English and French, accent-insensitive; pass lang 'en'|'fr' to narrow. terms is a single query string; the query is one OR-group of AND'd words. To find more, rephrase the user's question into 3-6 synonym queries with different vocabulary, include likely section names (e.g. 'troubleshooting', 'installation'), and retry with different words when results are weak or empty.
  DESCRIPTION
  input_schema(
    properties: {
      terms: { type: "string" },
      k: { type: "integer", default: 6 },
      lang: { type: "string", enum: [ "en", "fr" ] }
    },
    required: [ "terms" ]
  )

  class << self
    def call(terms:, k: 6, lang: nil)
      parsed = terms.to_s.split(/[| ]/).reject(&:blank?)
      return rephrase_response if Chunk.build_tsquery(parsed).nil?
      return invalid_lang_response unless lang.nil? || LANGUAGES.include?(lang)

      chunks = Chunk.search_for(parsed, k: k, languages: lang).includes(:document)
      payload = chunks.map { |chunk| row_payload(chunk) }
      MCP::Tool::Response.new([ { type: "text", text: payload.to_json } ])
    end

    private

    LANGUAGES = %w[en fr].freeze
    private_constant :LANGUAGES

    # kind is a literal until documents.kind lands with sub-feature H (H1f
    # swaps it for chunk.document.kind when the web corpus exists).
    def row_payload(chunk)
      { document: chunk.document.title, page: chunk.page, section: chunk.section_path, content: chunk.content, kind: "pdf", language: chunk.document.language }
    end

    def rephrase_response
      hint = { error: "terms contains no searchable words", hint: "rephrase the query with alphanumeric words and retry" }
      MCP::Tool::Response.new([ { type: "text", text: hint.to_json } ])
    end

    def invalid_lang_response
      error = { error: "lang must be 'en' or 'fr'", hint: "omit lang to search all languages" }
      MCP::Tool::Response.new([ { type: "text", text: error.to_json } ])
    end
  end
end
