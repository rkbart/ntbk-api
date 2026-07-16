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

  def attachments
    object.attachments.map do |attachment|
      {
        id: attachment.id,
        filename: attachment.filename,
        content_type: attachment.content_type,
        file_size: attachment.file_size,
        preview_state: attachment.preview_state,
        created_at: attachment.created_at&.iso8601
      }
    end
  end
end
