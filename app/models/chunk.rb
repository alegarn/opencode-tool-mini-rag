class Chunk < ApplicationRecord
  belongs_to :document

  # Matches the OR'd dual-config tsv: english half catches EN stems, french
  # half FR stems, immutable_unaccent on both binds keeps index and query in
  # one accent-insensitive form (single source of truth for the transform).
  scope :full_text, ->(tsq) {
    where("tsv @@ (to_tsquery('english', immutable_unaccent(?)) || to_tsquery('french', immutable_unaccent(?)))", tsq, tsq)
  }
  scope :in_section, ->(prefix) { where(arel_table[:section_path].matches(sanitize_sql_like(prefix) + "%")) }
  scope :in_reading_order, -> { order(:page, :id) }

  def self.build_tsquery(terms)
    queries = terms.filter_map do |term|
      # Unicode letters+digits runs keep accents and CJK alive; single-letter
      # tokens (l', d') are dropped — AND-terms that short degrade recall.
      words = term.to_s.scan(/[\p{L}\p{N}]+/).reject { |word| word.length <= 1 }
      words.join(" & ") if words.any?
    end
    queries.join(" | ").presence
  end

  # kind/languages filters apply INSIDE, before the fallback decision —
  # filtering downstream of search_for would starve the trigram fallback for
  # filtered-but-zero-hit queries. The binds are skipped when nil because
  # where(language: nil) would emit IS NULL and match nothing.
  def self.search_for(terms, k: 6, kind: nil, languages: nil)
    documents = Document.all
    documents = documents.where(language: languages) if languages
    documents = documents.where(kind: kind) if kind # documents.kind arrives with sub-feature H (H1a)
    scope = joins(:document).merge(documents)

    tsq = build_tsquery(terms)
    if tsq
      quoted = connection.quote(tsq)
      rank = Arel.sql("ts_rank_cd(tsv, to_tsquery('english', immutable_unaccent(#{quoted})) || to_tsquery('french', immutable_unaccent(#{quoted}))) DESC")
      results = scope.full_text(tsq).order(rank).limit(k)
      return results if results.any?
    end
    scope.where("similarity(content, ?) > 0.3", terms.first)
         .order(Arel.sql("similarity(content, #{connection.quote(terms.first.to_s)}) DESC"))
         .limit(k)
  end
end
