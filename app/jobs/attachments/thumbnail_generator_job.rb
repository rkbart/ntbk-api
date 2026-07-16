module Attachments
  class ThumbnailGeneratorJob < ApplicationJob
    queue_as :default

    def perform(attachment_id)
      attachment = Attachment.find(attachment_id)
      return unless attachment.file.attached?

      case attachment.content_type
      when /^image\//
        generate_image_thumbnail(attachment)
      when 'application/pdf'
        generate_pdf_thumbnail(attachment)
      else
        # No thumbnail needed
        attachment.update!(preview_state: 'completed')
      end
    rescue StandardError => e
      attachment.update!(preview_state: 'failed', metadata: {
        **attachment.metadata,
        'preview_error' => e.message
      })
      raise e
    end

    private

    def generate_image_thumbnail(attachment)
      attachment.file.open do |tempfile|
        thumbnail = ImageProcessing::MiniMagick
          .source(tempfile.path)
          .resize_to_limit(300, 300)
          .convert('png')
          .call

        attachment.thumbnail.attach(
          io: File.open(thumbnail.path),
          filename: "thumb_#{attachment.filename}",
          content_type: 'image/png'
        )

        # Update metadata with dimensions
        image = MiniMagick::Image.open(tempfile.path)
        attachment.update!(
          preview_state: 'completed',
          metadata: {
            **attachment.metadata,
            'dimensions' => { 'width' => image.width, 'height' => image.height },
            'thumbnail_generated' => true
          }
        )
      end
    end

    def generate_pdf_thumbnail(attachment)
      # Use MiniMagick to convert first page
      attachment.file.open do |tempfile|
        image = MiniMagick::Image.open(tempfile.path)
        image.format('png')
        image.pages.first
        image.resize '300x300'

        attachment.thumbnail.attach(
          io: File.open(image.path),
          filename: "thumb_#{attachment.filename}.png",
          content_type: 'image/png'
        )

        # Get page count (simplified - in production use a PDF library)
        page_count = 1

        attachment.update!(
          preview_state: 'completed',
          metadata: {
            **attachment.metadata,
            'page_count' => page_count,
            'thumbnail_generated' => true
          }
        )
      end
    end
  end
end
