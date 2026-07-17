module Attachments
  class TextExtractionJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(attachment_id)
      attachment = Attachment.find(attachment_id)

      # Skip if already processed
      return if attachment.metadata["text_extracted"]

      # Extract text content
      service = TextExtractionService.new(attachment)
      text_content = service.extract

      if text_content.present?
        # Store extracted text in metadata
        attachment.update!(
          metadata: attachment.metadata.merge(
            "text_content" => text_content,
            "text_length" => text_content.length,
            "text_extracted" => true,
            "text_extracted_at" => Time.current.iso8601
          )
        )

        # Update document body with extracted text (if document body is empty)
        document = attachment.document
        if document.body.blank? && text_content.present?
          document.update!(body: text_content)
        end

        # Trigger re-embedding
        update_document_embedding(document)

        Rails.logger.info "Extracted text from attachment #{attachment_id}: #{text_content.length} chars"
      else
        attachment.update!(
          metadata: attachment.metadata.merge(
            "text_extracted" => false,
            "text_extraction_error" => "No text content could be extracted"
          )
        )
      end
    rescue => e
      Rails.logger.error "Text extraction failed for attachment #{attachment_id}: #{e.message}"
      attachment.update!(
        metadata: attachment.metadata.merge(
          "text_extracted" => false,
          "text_extraction_error" => e.message
        )
      )
    end

    private

    def update_document_embedding(document)
      if document.class.column_names.include?("embedding")
        document.update!(embedding: nil)
        DocumentEmbeddingJob.perform_later(document.id)
      end
    end
  end
end
