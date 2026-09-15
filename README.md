# mini-rag

RAG over ingested PDFs without embeddings: Postgres full-text search (`tsvector` + `pg_trgm` fallback) exposed over REST and MCP.

## Setup

```
bundle install
bin/rails db:prepare
```

## MCP server

The app mounts an MCP server at `/mcp` (Streamable HTTP, stateless, JSON responses) exposing the ingested PDFs to MCP clients (opencode, Claude, etc.).

Run the server:

```
bin/rails server
```

opencode configuration (`opencode.json`):

```json
{
  "mcp": {
    "pdf-rag": {
      "type": "remote",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

### Tools

- `search_pdfs` — full-text search over PDF chunks. `terms` is a single query string; the query is one OR-group of AND'd words. Rephrase the user's question into 3-6 synonym queries with different vocabulary, include likely section names (e.g. 'troubleshooting', 'installation'), and retry with different words when results are weak or empty. Optional `k` (default 6) caps the number of chunks.
- `list_toc` — table of contents of all ingested documents with section paths and chunk counts; use it to pick promising sections before searching or reading.
- `read_section` — every chunk of one document section (`document_id` + `section_prefix`), ordered by page.

Search follows the semantic protocol above: first translate the user's question into several rephrased queries, then call `search_pdfs` with each, then `read_section` on the most promising hits.

### Ingesting PDFs

```
curl -X POST http://localhost:3000/documents -H "Content-Type: application/json" -d '{"path": "/abs/path/doc.pdf"}'
curl http://localhost:3000/documents
curl "http://localhost:3000/chunks?terms=printer|cups&k=6"
curl "http://localhost:3000/documents/1/sections?prefix=Doc%20Title%20/%20Section"
```

PDFs whose text layer cannot be extracted (image-only scans) are out of scope.

## Tests

```
bin/rails test
```
