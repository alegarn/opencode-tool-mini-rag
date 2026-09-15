Rails.application.config.to_prepare do
  Rails.application.config.mcp_transport = MCP::Server::Transports::StreamableHTTPTransport.new(
    MCP::Server.new(
      name: "pdf-rag",
      version: "0.1.0",
      tools: [ SearchPdfsTool, ListTocTool, ReadSectionTool ]
    ),
    stateless: true,
    enable_json_response: true
  )
end
