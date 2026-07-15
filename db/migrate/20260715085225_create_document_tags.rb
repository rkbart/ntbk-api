class CreateDocumentTags < ActiveRecord::Migration[8.1]
  def change
    create_table :document_tags do |t|
      t.references :document, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.datetime :created_at, null: false
    end

    add_index :document_tags, [ :document_id, :tag_id ], unique: true
  end
end
