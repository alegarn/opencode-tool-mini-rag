# db — Schema Source of Truth

## Purpose

Postgres schema: FTS (tsvector + pg_trgm), ActiveStorage, documents/chunks/images. Schema lives in `db/structure.sql`, NOT `db/schema.rb`.

## Ownership

- `config.active_record.schema_format = :sql` (config/application.rb) — permanent project setting

## Local Contracts

- WHY structure.sql: the tsv generated column calls the custom SQL function `immutable_unaccent(text)`. The ruby dumper cannot express functions, so `schema.rb` would load a schema referencing a nonexistent function and `db:test:prepare` fails. `structure.sql` is the Rails-blessed format for PG objects AR cannot dump. Cost accepted: PG-only schema, larger diffs.
- Function bodies MUST schema-qualify (`public.unaccent('public.unaccent', $1)`) — structure.sql reloads with empty `search_path`; bare names break reload.
- Generated-column expressions MUST be IMMUTABLE → wrappers required for stable functions (`unaccent` is only stable).
- tsv expression enumerates supported language configs (`'english' || 'french'`, both wrapped in `immutable_unaccent`, weights section `'A'` > content `'B'`). Adding a language = new stopwords entry + migration rebuilding tsv with one more config term.
- Migrations are SELF-CONTAINED: no app-model/PORO references (rot on refactor, break zero-downtime replays). Backfills inline their data (see stopword backfill in the multilanguage migration).
- tsv rebuild = `remove_column` + re-add (PG cannot ALTER a generated expression); full table rewrite, acceptable at this scale.

## Work Guidance

- After migrating: `db:test:prepare` must pass from structure.sql before anything else is trusted.

## Verification

- `rtk mise exec -- bundle exec rails db:migrate && rtk mise exec -- bundle exec rails db:test:prepare`
- Suite green (`rails test`) proves structure.sql loads.

## Child DOX Index

(none)
