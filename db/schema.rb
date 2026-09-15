# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_15_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "chunks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.integer "page"
    t.string "section_path", null: false
    t.virtual "tsv", type: :tsvector, as: "(setweight(to_tsvector('english'::regconfig, (COALESCE(section_path, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector('english'::regconfig, content), 'B'::\"char\"))", stored: true
    t.datetime "updated_at", null: false
    t.index ["content"], name: "index_chunks_on_content", opclass: :gin_trgm_ops, using: :gin
    t.index ["document_id"], name: "index_chunks_on_document_id"
    t.index ["tsv"], name: "index_chunks_on_tsv", using: :gin
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "source_path", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["source_path"], name: "index_documents_on_source_path", unique: true
  end

  add_foreign_key "chunks", "documents"
end
