# mini-rag

RAG over ingested PDFs without embeddings: Postgres full-text search (`tsvector` + `pg_trgm` fallback) exposed over REST and MCP. English + French, accent-insensitive. Images (figures) with caption/section/page provenance. PDF metadata + idempotent re-ingest.

## Setup

```
bundle install
bin/rails db:prepare
```

Schema ships as `db/structure.sql` (`schema_format = :sql`): the tsv generated column depends on a custom SQL function (`immutable_unaccent`) that Ruby's schema dumper cannot express. Do not switch back to `schema.rb`.

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

- `search_pdfs` — full-text search over document chunks (PDFs today; web pages once H lands). `terms` is a single query string; the query is one OR-group of AND'd words (`a b|c d` = `(a & b) | (c & d)`). Rephrase the user's question into 3-6 synonym queries with different vocabulary, include likely section names, retry with different words when results are weak. Optional `k` (default 6), `kind` (`pdf`|`web`, H), `lang` (`en`|`fr`, absent = all).
- `list_toc` — table of contents of all ingested documents (section paths, chunk counts, `kind`, `language`, metadata summary); use it to pick promising sections before searching or reading.
- `read_section` — every chunk of one document section (`document_id` + `section_prefix`) in reading order.
- `find_images` — figures by caption/section vocabulary (2-4 short keywords, not phrases): returns legend (caption when present), section, page, dimensions, same-page text (`context_text`), and a `file_url` when the image bytes were storable (JPEG/JPEG2000 passthrough only).

### Multilingual retrieval (EN + FR)

- Each chunk is indexed under BOTH `english` and `french` tsvector configs, wrapped in `immutable_unaccent` → stemming per language, accent-insensitive both directions (`etancheite` finds `étanchéité` and vice versa).
- `language` is detected per document (stopword frequency) at ingest, stored, filterable (`?lang=fr`, tool `lang` param), and returned on every search row.
- There is NO server-side translation. Cross-language semantic bridging is the CLIENT model's job: translate query terms into the corpus languages before calling `search_pdfs` (see the tool description). "Caulking" will not find "calfeutrage" unless the model passes both — as pipe-separated groups in ONE call (`caulking window | calfeutrage fenêtre`), never one search per language.
- opencode users can enforce the rule ABOVE the tool layer too, as a global agent instruction:

  ```
  Before calling pdf-rag search_pdfs/find_images: translate the question's key
  terms into every language present in list_toc output and pass them as one
  pipe-separated terms string (group per language). Never issue per-language calls.
  ```

### Ingesting PDFs

```
curl -X POST http://localhost:3000/documents -H "Content-Type: application/json" -d '{"path": "/abs/path/doc.pdf"}'
curl http://localhost:3000/documents          # ToC + metadata + language
curl http://localhost:3000/documents/1        # one doc: metadata, ToC, counts
curl "http://localhost:3000/chunks?terms=printer|cups&k=6&lang=en"
curl "http://localhost:3000/documents/1/sections?prefix=Doc%20Title%20/%20Section"
curl "http://localhost:3000/images?terms=sealing%20detail&document_id=1"
curl -L "http://localhost:3000<file_url>"     # image bytes (follow the 302)
```

- `POST /documents` is idempotent: same file → `200` + same id (SHA256 digest), new/changed → `201`.
- Image extraction: JPEG (DCTDecode) and JPEG2000 stored as blobs; Flate/LZW/CCITT images kept metadata-only (no pixel re-encode dependency). Image-only scans (no text layer) are out of scope — no OCR.

## Tests

```
bin/rails test
```
