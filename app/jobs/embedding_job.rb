class EmbeddingJob < ApplicationJob
  queue_as :ai

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(workspace_id)
    workspace = Workspace.find(workspace_id)
    documents = workspace.documents.active.where(embedding: nil)

    service = EmbeddingService.new
    service.embed_documents(documents)

    Rails.logger.info "Generated embeddings for #{documents.count} documents in workspace #{workspace_id}"
  end
end
