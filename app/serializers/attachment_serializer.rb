class AttachmentSerializer < ActiveModel::Serializer
  attributes :id, :filename, :content_type, :file_size, :metadata,
             :preview_state, :created_at, :updated_at

  attribute :human_file_size
  attribute :file_extension
  attribute :download_url
  attribute :preview_url
  attribute :thumbnail_generated

  def human_file_size
    object.human_file_size
  end

  def file_extension
    object.file_extension
  end

  def download_url
    return nil unless object.file.attached?

    "/api/v1/workspaces/#{object.document.workspace_id}/documents/#{object.document_id}/attachments/#{object.id}/download"
  end

  def preview_url
    return nil unless object.thumbnail.attached?

    object.thumbnail.url
  end

  def thumbnail_generated
    object.thumbnail.attached?
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
