class Chunk < ApplicationRecord
  belongs_to :document

  scope :full_text, ->(tsq) { where("tsv @@ to_tsquery('english', ?)", tsq) }
  scope :in_section, ->(prefix) { where(arel_table[:section_path].matches(sanitize_sql_like(prefix) + "%")) }

  def self.build_tsquery(terms)
    queries = terms.filter_map do |term|
      words = term.to_s.scan(/[a-zA-Z0-9]+/)
      words.join(" & ") if words.any?
    end
    queries.join(" | ").presence
  end

  def self.search_for(terms, k: 6)
    tsq = build_tsquery(terms)
    if tsq
      results = full_text(tsq).order(Arel.sql("ts_rank_cd(tsv, to_tsquery('english', #{connection.quote(tsq)})) DESC")).limit(k)
      return results if results.any?
    end
    where("similarity(content, ?) > 0.3", terms.first).order(Arel.sql("similarity(content, #{connection.quote(terms.first.to_s)}) DESC")).limit(k)
  end
end
