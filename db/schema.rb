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

ActiveRecord::Schema[8.1].define(version: 2026_09_15_124918) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.string "digest"
    t.jsonb "metadata", default: {}, null: false
    t.integer "page_count"
    t.string "pdf_version"
    t.string "source_path", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["digest"], name: "index_documents_on_digest"
    t.index ["source_path"], name: "index_documents_on_source_path", unique: true
  end

  create_table "images", force: :cascade do |t|
    t.string "caption"
    t.string "color_space"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.bigint "document_id", null: false
    t.string "filter"
    t.integer "height"
    t.string "name", null: false
    t.integer "page", null: false
    t.string "section_path", null: false
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["caption"], name: "index_images_on_caption", opclass: :gin_trgm_ops, using: :gin
    t.index ["document_id", "page", "name"], name: "index_images_on_document_id_and_page_and_name", unique: true
    t.index ["document_id"], name: "index_images_on_document_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chunks", "documents"
  add_foreign_key "images", "documents"
end
