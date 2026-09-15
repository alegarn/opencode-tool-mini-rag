class SwapTsvWeightsSectionAboveBody < ActiveRecord::Migration[8.1]
  SECTION_A_BODY_B = "(setweight(to_tsvector('english'::regconfig, (COALESCE(section_path, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector('english'::regconfig, content), 'B'::\"char\"))"
  SECTION_B_BODY_A = "(setweight(to_tsvector('english'::regconfig, (COALESCE(section_path, ''::character varying))::text), 'B'::\"char\") || setweight(to_tsvector('english'::regconfig, content), 'A'::\"char\"))"

  def up
    change_tsv SECTION_A_BODY_B
  end

  def down
    change_tsv SECTION_B_BODY_A
  end

  private

  def change_tsv(expression)
    remove_index :chunks, :tsv
    remove_column :chunks, :tsv
    add_column :chunks, :tsv, :tsvector, as: expression, stored: true
    add_index :chunks, :tsv, using: :gin
  end
end
