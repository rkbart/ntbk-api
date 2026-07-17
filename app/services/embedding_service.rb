class EmbeddingService
  CHUNK_SIZE = 1000  # Characters per chunk
  CHUNK_OVERLAP = 200

  def initialize(provider: nil)
    @client = LlmClientFactory.create(provider)
  end

  # Generate embedding for a document
  def embed_document(document)
    text = document.embedding_text
    return if text.blank?

    # Check if pgvector is available
    begin
      embedding = @client.embed(text)
      document.update!(embedding: embedding) if embedding.present?
    rescue => e
      Rails.logger.warn "Failed to generate embedding: #{e.message}"
      nil
    end
  end

  # Generate embeddings for multiple documents (batch)
  def embed_documents(documents)
    documents.find_each do |document|
      embed_document(document)
      sleep(0.1)  # Rate limiting
    end
  end

  # Semantic search within a specific workspace
  def search(query, workspace:, limit: 10, threshold: 0.5)
    # Check if pgvector is available
    begin
      query_embedding = @client.embed(query)
      return [] if query_embedding.nil?

      # Search ONLY within the specified workspace
      Document.where(workspace_id: workspace.id)
              .active
              .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
              .first(limit)
              .select { |doc| doc.neighbor_distance <= threshold }
    rescue => e
      Rails.logger.warn "Semantic search not available: #{e.message}"
      []
    end
  end

  # Find similar documents
  def similar_documents(document, limit: 5)
    return [] unless document.respond_to?(:embedding) && document.embedding.present?

    begin
      Document.where(workspace: document.workspace)
              .active
              .where.not(id: document.id)
              .nearest_neighbors(:embedding, document.embedding, distance: "cosine")
              .first(limit)
    rescue => e
      Rails.logger.warn "Similar documents search not available: #{e.message}"
      []
    end
  end
end
