class AddEmbeddingToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :embedding, :vector, limit: 768
    add_index :documents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
