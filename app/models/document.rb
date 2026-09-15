class Document < ApplicationRecord
  has_many :chunks, dependent: :delete_all
  validates :title, :source_path, presence: true

  def self.ingest!(path)
    transaction do
      find_by(source_path: path)&.destroy
      create!(title: File.basename(path, ".pdf"), source_path: path).then do |document|
        now = Time.current
        Chunk.insert_all!(Chunk::Extractor.new(document, path).rows.map { |row| row.merge(created_at: now, updated_at: now) })
        document
      end
    end
  end
end
