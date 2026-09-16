class Image < ApplicationRecord
  belongs_to :document
  has_one_attached :file

  # Groups follow the shared terms grammar (pipe-separated, OR'd across
  # groups): an image scores by the group it resembles MOST, so a translated
  # sibling group never dilutes the similarity below its own match.
  def self.search_for(terms, k: 6)
    scores = terms.to_s.split("|").map(&:strip).reject(&:blank?).map do |group|
      "similarity(coalesce(caption, '') || ' ' || section_path, #{connection.quote(group)})"
    end
    return none if scores.empty?

    best = Arel.sql("greatest(#{scores.join(', ')})")
    where("#{best} > 0.3").order(best.desc).limit(k)
  end

  def context_text
    Chunk.where(document_id: document_id, page: page).order(:id).pluck(:content).join("\n---\n")
  end
end
