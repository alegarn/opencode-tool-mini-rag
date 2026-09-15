class ReadSectionTool < MCP::Tool
  tool_name "read_section"
  description <<~DESCRIPTION
    Read every chunk of one document section, ordered by page. Use after search_pdfs or list_toc with an exact or prefix section path to pull full content.
  DESCRIPTION
  input_schema(
    properties: {
      document_id: { type: "integer" },
      section_prefix: { type: "string" }
    },
    required: [ "document_id", "section_prefix" ]
  )

  class << self
    def call(document_id:, section_prefix:)
      document = Document.find_by(id: document_id)
      return missing_response("document #{document_id} not found; call list_toc for valid document ids") unless document

      rows = document.chunks.in_section(section_prefix).order(:page).pluck(:page, :section_path, :content)
      if rows.empty?
        return missing_response("no chunks under section prefix #{section_prefix.inspect} in #{document.title}; call list_toc to inspect section paths")
      end

      payload = rows.map { |page, section, content| { page: page, section: section, content: content } }
      MCP::Tool::Response.new([ { type: "text", text: payload.to_json } ])
    end

    private

    def missing_response(message)
      MCP::Tool::Response.new([ { type: "text", text: { error: message }.to_json } ])
    end
  end
end
