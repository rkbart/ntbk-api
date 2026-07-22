class DocumentSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :folder_id, :archived_at, :created_at, :updated_at

  belongs_to :folder
  has_many :tags

  attribute :attachments_count
  attribute :attachments_size
  attribute :attachments

  def archived_at
    object.archived_at&.iso8601
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end

  def attachments_count
    object.attachments_count
  end

  def attachments_size
    object.attachments_size_sum
  end

  attribute :extraction_status

  def extraction_status
    attachments = object.attachments.to_a
    return "none" if attachments.empty?

    all_extracted = attachments.all? { |a| a.metadata&.dig("text_extracted") == true }
    any_extracted = attachments.any? { |a| a.metadata&.dig("text_extracted") == true }
    any_failed = attachments.any? { |a| a.metadata&.dig("text_extraction_error").present? }

    return "completed" if all_extracted
    return "failed" if any_failed && !any_extracted
    return "partial" if any_extracted
    "processing"
  end

  def attachments
    object.attachments.map do |attachment|
      {
        id: attachment.id,
        filename: attachment.filename,
        content_type: attachment.content_type,
        file_size: attachment.file_size,
        preview_state: attachment.preview_state,
        text_extracted: attachment.metadata&.dig("text_extracted") == true,
        text_extraction_error: attachment.metadata&.dig("text_extraction_error"),
        created_at: attachment.created_at&.iso8601
      }
    end
  end
end
