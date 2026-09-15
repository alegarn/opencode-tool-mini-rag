class CreateMiniRagSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :documents do |t|
      t.string :title, null: false
      t.string :source_path, null: false
      t.timestamps
    end

    add_index :documents, :source_path, unique: true

    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :page
      t.string :section_path, null: false
      t.virtual :tsv, type: :tsvector, stored: true, as: "setweight(to_tsvector('english', coalesce(section_path,'')), 'B') || setweight(to_tsvector('english', content), 'A')"
      t.timestamps
    end

    add_index :chunks, :tsv, using: :gin
    add_index :chunks, :content, opclass: :gin_trgm_ops, using: :gin
  end
end
