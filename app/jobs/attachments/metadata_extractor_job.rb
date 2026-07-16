module Attachments
  class MetadataExtractorJob < ApplicationJob
    queue_as :default

    def perform(attachment_id)
      attachment = Attachment.find(attachment_id)
      return unless attachment.file.attached?

      metadata = {}

      case attachment.content_type
      when /^image\//
        extract_image_metadata(attachment, metadata)
      when 'application/pdf'
        extract_pdf_metadata(attachment, metadata)
      when /^text\//
        extract_text_metadata(attachment, metadata)
      end

      # Always add checksum
      checksum = Digest::SHA256.hexdigest(attachment.file.download)
      metadata['checksum'] = checksum

      attachment.update!(metadata: metadata)
    end

    private

    def extract_image_metadata(attachment, metadata)
      attachment.file.open do |tempfile|
        image = MiniMagick::Image.open(tempfile.path)
        metadata['dimensions'] = { 'width' => image.width, 'height' => image.height }
        metadata['colorspace'] = image.data['colorspace']
      end
    end

    def extract_pdf_metadata(attachment, metadata)
      # Simplified - in production use a PDF library like PDF::Reader
      metadata['page_count'] = 1
    end

    def extract_text_metadata(attachment, metadata)
      content = attachment.file.download
      metadata['line_count'] = content.lines.count
      metadata['char_count'] = content.length
    end
  end
end
