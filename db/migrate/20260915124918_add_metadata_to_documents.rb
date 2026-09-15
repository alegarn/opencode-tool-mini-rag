class AddMetadataToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :metadata, :jsonb, null: false, default: {}
    add_column :documents, :digest, :string
    add_column :documents, :page_count, :integer
    add_column :documents, :pdf_version, :string
    add_index :documents, :digest
  end
end
