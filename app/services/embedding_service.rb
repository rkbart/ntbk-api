class EmbeddingService
  CHUNK_SIZE = 1000  # Characters per chunk
  CHUNK_OVERLAP = 200

  def initialize
    @client = OllamaClient.new
  end

  # Generate embedding for a document
  def embed_document(document)
    text = document.embedding_text
    return if text.blank?

    embedding = @client.embed(text)
    document.update!(embedding: embedding)
  end

  # Generate embeddings for multiple documents (batch)
  def embed_documents(documents)
    documents.find_each do |document|
      embed_document(document)
      sleep(0.1)  # Rate limiting for local Ollama
    end
  end

  # Semantic search within a workspace
  def search(query, workspace:, limit: 10, threshold: 0.5)
    query_embedding = @client.embed(query)

    Document.joins(:workspace)
            .where(workspaces: { user_id: workspace.user_id })
            .active
            .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
            .first(limit)
            .select { |doc| doc.neighbor_distance <= threshold }
  end

  # Find similar documents
  def similar_documents(document, limit: 5)
    return [] unless document.embedding.present?

    Document.where(workspace: document.workspace)
            .active
            .where.not(id: document.id)
            .nearest_neighbors(:embedding, document.embedding, distance: "cosine")
            .first(limit)
  end
end
