class CreateImages < ActiveRecord::Migration[8.1]
  def change
    create_table :images do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :page, null: false
      t.string :section_path, null: false
      t.string :caption
      t.string :name, null: false
      t.string :content_type
      t.integer :width
      t.integer :height
      t.string :color_space
      t.string :filter
      t.string :digest, null: false
      t.timestamps
    end
    add_index :images, [ :document_id, :page, :name ], unique: true
    add_index :images, :caption, opclass: :gin_trgm_ops, using: :gin
  end
end
