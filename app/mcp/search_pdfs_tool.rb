class SearchPdfsTool < MCP::Tool
  tool_name "search_pdfs"
  description <<~DESCRIPTION
    Full-text search over ingested PDF chunks. terms is a single query string; the query is one OR-group of AND'd words. To find more, rephrase the user's question into 3-6 synonym queries with different vocabulary, include likely section names (e.g. 'troubleshooting', 'installation'), and retry with different words when results are weak or empty.
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

      chunks = Chunk.search_for(terms.split(/[| ]/).reject(&:blank?), k: k)
      payload = chunks.map do |chunk|
        { document: chunk.document.title, page: chunk.page, section: chunk.section_path, content: chunk.content }
      end
      MCP::Tool::Response.new([ { type: "text", text: payload.to_json } ])
    end

    private

    def rephrase_response
      hint = { error: "terms contains no searchable words", hint: "rephrase the query with alphanumeric words and retry" }
      MCP::Tool::Response.new([ { type: "text", text: hint.to_json } ])
    end
  end
end
