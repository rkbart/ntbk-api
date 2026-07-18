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
        # Extract tags from content
        extracted_tags = service.extract_tags(text_content)

        # Remove tags section from content
        cleaned_content = service.remove_tags_from_content(text_content)

        # Store extracted text in metadata
        attachment.update!(
          metadata: attachment.metadata.merge(
            "text_content" => text_content,
            "cleaned_content" => cleaned_content,
            "text_length" => cleaned_content.length,
            "extracted_tags" => extracted_tags,
            "text_extracted" => true,
            "text_extracted_at" => Time.current.iso8601
          )
        )

        # Update document body with cleaned content (if document body is empty)
        document = attachment.document
        if document.body.blank? && cleaned_content.present?
          document.update!(body: cleaned_content)
        end

        # Create and attach tags to document
        if extracted_tags.any?
          create_document_tags(document, extracted_tags)
        end

        # Trigger re-embedding
        update_document_embedding(document)

        Rails.logger.info "Extracted text from attachment #{attachment_id}: #{cleaned_content.length} chars, #{extracted_tags.length} tags"
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

    def create_document_tags(document, tag_names)
      tag_names.each do |tag_name|
        # Find or create tag for the user
        tag = document.workspace.user.tags.find_or_create_by!(
          name: tag_name.downcase.strip
        )

        # Associate tag with document if not already associated
        unless document.tags.include?(tag)
          document.tags << tag
        end
      end
    rescue => e
      Rails.logger.error "Failed to create tags for document #{document.id}: #{e.message}"
    end

    def update_document_embedding(document)
      if document.class.column_names.include?("embedding")
        document.update!(embedding: nil)
        DocumentEmbeddingJob.perform_later(document.id)
      end
    end
  end
end
