class AddEmbeddingToDocuments < ActiveRecord::Migration[8.1]
  def up
    # Check if pgvector extension is available
    begin
      # Test if vector type is available
      connection.execute("SELECT '1'::vector")
      add_column :documents, :embedding, :vector, limit: 768
      add_index :documents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    rescue ActiveRecord::StatementInvalid, PG::UndefinedObject => e
      puts "WARNING: pgvector not available, skipping embedding column"
      puts "Install pgvector: https://github.com/pgvector/pgvector#installation"
    end
  end

  def down
    begin
      remove_index :documents, :embedding
      remove_column :documents, :embedding
    rescue ActiveRecord::StatementInvalid
      # Column might not exist
    end
  end
end
