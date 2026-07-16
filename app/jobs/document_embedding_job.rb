class DocumentEmbeddingJob < ApplicationJob
  queue_as :ai

  def perform(document_id)
    document = Document.find(document_id)
    service = EmbeddingService.new
    service.embed_document(document)
  end
end
