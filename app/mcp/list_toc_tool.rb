class ListTocTool < MCP::Tool
  tool_name "list_toc"
  description <<~DESCRIPTION
    Table of contents of all ingested PDFs: each document with its section paths and chunk counts. Use it to pick promising sections before searching or reading.
  DESCRIPTION

  class << self
    def call
      rows = Chunk.joins(:document)
                  .select("documents.id, documents.title, chunks.section_path, count(*) AS chunks")
                  .group("documents.id", "documents.title", "chunks.section_path")
                  .order("documents.title, chunks.section_path")
      payload = rows.each_with_object([]) do |row, documents|
        documents << { id: row.id, document: row.title, sections: [] } if documents.last&.fetch(:id) != row.id
        documents.last[:sections] << { path: row.section_path, chunks: row.chunks }
      end
      MCP::Tool::Response.new([ { type: "text", text: payload.to_json } ])
    end
  end
end
