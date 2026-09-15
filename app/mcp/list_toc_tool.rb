class ListTocTool < MCP::Tool
  tool_name "list_toc"
  description <<~DESCRIPTION
    Table of contents of all ingested PDFs: each document with its section paths, chunk counts, and a metadata summary (title, author, page count). Use it to pick promising sections before searching or reading.
  DESCRIPTION

  class << self
    def call
      MCP::Tool::Response.new([ { type: "text", text: Document.toc.to_json } ])
    end
  end
end
