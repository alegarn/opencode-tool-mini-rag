# app/models — Domain Layer

## Purpose

Document/Chunk/Image models, retrieval seams, and ingest orchestration. All domain behavior lives here.

## Ownership

- Retrieval query logic: `Chunk.search_for`, `Image.search_for` (controllers and MCP tools call these — never duplicate SQL at the edge)
- ToC shaping: `Document.toc` / `Document#toc` (REST and `list_toc` both consume)
- Section attribution: `HeadingTracker` (two detector lambdas: PDF line heuristic, markdown prefix)
- Language: `LanguageDetector` (stopword frequency, `:en` default)

## Local Contracts

- No `app/services/`. Domain POROs live here as namespaced classes (`Chunk::Extractor`, `Image::Extractor`, `Chunk::MarkdownExtractor` planned in H).
- Bang methods internally; HTTP error mapping happens in controllers only.
- Ingest invariants:
  - tsv weights: section_path `'A'` > content `'B'` (E1b test guards this — byte-untouched requirement)
  - digest early-return on unchanged source (`find_by(source_path)&.digest == digest`)
  - ActiveStorage uploads/purges NEVER inside the DB transaction (rollback cannot undo `File.delete`)
  - UTF-8 scrub on PDF info-dict strings before jsonb serialize
- Search fallback order: FTS (dual-config en/fr + `immutable_unaccent`) → trigram similarity > 0.3. Filters (`kind`, `languages`) apply INSIDE `search_for`, before the fallback decision.

## Work Guidance

- All ranking/filtering/sorting in SQL. `pluck` over `map`.
- Adding a language = `LanguageDetector::STOPWORDS` entry + tsv rebuild migration (see `db/AGENTS.md`).

## Verification

- `rtk mise exec -- bundle exec rails test` from repo root
- `rtk mise exec -- bundle exec rubocop`

## Child DOX Index

- `chunk/` — extractor (PDF text) + markdown extractor (H, planned); `Chunk::Windows` constants shared by both
- `image/` — image XObject extraction (DCT/JPX passthrough; other filters metadata-only)
