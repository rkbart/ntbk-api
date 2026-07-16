class AddTrigramIndexToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_index :documents, [ :title, :body ], using: :gin,
              opclass: :gin_trgm_ops,
              name: 'index_documents_on_title_body_trigram'
  end
end
