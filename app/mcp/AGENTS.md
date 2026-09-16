# app/mcp — MCP Tool Layer

## Purpose

Streamable-HTTP MCP surface at `/mcp`. One narrow tool per capability (ISP); tools adapt protocol, models do the work.

## Ownership

- Tool classes: `SearchPdfsTool`, `ListTocTool`, `ReadSectionTool`, `FindImagesTool` (+ `IngestWebTool` planned in H)
- Registry: tools array in `config/initializers/mcp.rb` — the SINGLE append point for new tools (OCP)

## Local Contracts

- Tools call model seams directly (`Chunk.search_for`, `Document.toc`, `Image.search_for`) — no Net::HTTP, no self-REST calls (DIP).
- Tool `description` strings are LOAD-BEARING: they carry the agent-facing semantic protocol (rephrase, TRANSLATE-THEN-SEARCH, retry instructions). Changing a description changes client behavior.
- `terms` grammar is shared across tools and REST: pipe-separated groups, words AND'd within a group, groups OR'd (`a b|c d` = `(a & b) | (c & d)`). Tool-side parsing splits `|` only — a space-split would flatten groups into single-word ORs. One translated group per corpus language rides the same grammar (query-translation sub-feature J).
- Explicit `tool_name` required (class-derived name would be `search_pdfs_tool`).
- Tools return `MCP::Tool::Response` text (JSON payload); errors are friendly text responses, never exceptions, never HTTP codes.
- Schema-level enums validate constrained params (`lang: ['en','fr']`) before the tool body runs.

## Work Guidance

- Transport mount: `config/routes.rb` (`StreamableHTTPTransport`, stateless, JSON mode). Server built in `to_prepare` (dev reload safe).
- Keep descriptions tight; they travel in every `tools/list`.

## Verification

- `rtk mise exec -- bundle exec rails test` (test/mcp/tools_test.rb)
- Manual: stateless JSON-RPC `initialize` → `tools/list` → `tools/call` against `/mcp`

## Child DOX Index

(none)
