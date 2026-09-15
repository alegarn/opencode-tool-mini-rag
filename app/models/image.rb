class Image < ApplicationRecord
  belongs_to :document
  has_one_attached :file

  def self.search_for(terms, k: 6)
    query = terms.to_s
    where("similarity(coalesce(caption, '') || ' ' || section_path, ?) > 0.3", query)
      .order(Arel.sql("similarity(coalesce(caption, '') || ' ' || section_path, #{connection.quote(query)}) DESC"))
      .limit(k)
  end

  def context_text
    Chunk.where(document_id: document_id, page: page).order(:id).pluck(:content).join("\n---\n")
  end
end
