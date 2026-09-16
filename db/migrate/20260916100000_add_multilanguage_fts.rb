class AddMultilanguageFts < ActiveRecord::Migration[8.1]
  DUAL_TSV = <<~SQL.squish
    (setweight(to_tsvector('english', immutable_unaccent(coalesce(section_path, ''))), 'A') ||
     setweight(to_tsvector('english', immutable_unaccent(content)), 'B') ||
     setweight(to_tsvector('french', immutable_unaccent(coalesce(section_path, ''))), 'A') ||
     setweight(to_tsvector('french', immutable_unaccent(content)), 'B'))
  SQL
  private_constant :DUAL_TSV

  SINGLE_TSV = <<~SQL.squish
    (setweight(to_tsvector('english', (COALESCE(section_path, ''::character varying))::text), 'A') ||
     setweight(to_tsvector('english', content), 'B'))
  SQL
  private_constant :SINGLE_TSV

  # Inlined duplicate of LanguageDetector::STOPWORDS (I1b) — migrations must
  # stay self-contained: referencing the app PORO rots on refactor and breaks
  # fresh db:migrate replays. Keep both lists in sync when adding a language.
  STOPWORDS = {
    "en" => %w[the and of to in is for that with are this be on],
    "fr" => %w[le la les de des du et est une un dans pour que qui pas au aux]
  }.freeze
  private_constant :STOPWORDS

  def up
    enable_extension "unaccent"
    # Body must schema-qualify the function AND the dictionary: structure.sql
    # reloads with an empty search_path, where bare unaccent(...) would not
    # resolve and db:test:prepare would die on the chunks table.
    connection.execute <<~SQL
      CREATE FUNCTION immutable_unaccent(text) RETURNS text
      AS $$ SELECT public.unaccent('public.unaccent', $1) $$
      LANGUAGE sql IMMUTABLE
    SQL

    add_column :documents, :language, :string, null: false, default: "en"
    add_index :documents, :language

    remove_index :chunks, :tsv
    remove_column :chunks, :tsv
    add_column :chunks, :tsv, :tsvector, as: DUAL_TSV, stored: true
    add_index :chunks, :tsv, using: :gin

    backfill_languages
  end

  def down
    remove_index :chunks, :tsv
    remove_column :chunks, :tsv
    add_column :chunks, :tsv, :tsvector, as: SINGLE_TSV, stored: true
    add_index :chunks, :tsv, using: :gin

    remove_index :documents, :language
    remove_column :documents, :language
    connection.execute "DROP FUNCTION immutable_unaccent(text)"
    disable_extension "unaccent"
  end

  private

  # Detector parity with I1b applied to pre-existing rows: stopwords scored
  # over the joined chunk contents, first ~2000 words, en on tie/empty/weak.
  def backfill_languages
    say_with_time "Backfilling documents.language" do
      connection.select_rows(
        "SELECT id, (SELECT string_agg(content, ' ') FROM chunks WHERE document_id = documents.id) FROM documents"
      ).each do |id, text|
        connection.execute(
          "UPDATE documents SET language = #{connection.quote(detect_language(text))} WHERE id = #{connection.quote(id)}"
        )
      end
    end
  end

  def detect_language(text)
    words = text.to_s.downcase.scan(/\p{L}+/).first(2000)
    return "en" if words.empty?

    scores = STOPWORDS.transform_values { |stopwords| words.count { |word| stopwords.include?(word) }.fdiv(words.size) }
    best = scores.max_by { |_language, score| score }
    return "en" if best[1] < 0.01

    best[0] # tie resolves to "en": it leads the STOPWORDS map
  end
end
