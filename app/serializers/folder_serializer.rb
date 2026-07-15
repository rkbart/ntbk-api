class FolderSerializer < ActiveModel::Serializer
  attributes :id, :name, :parent_id, :document_count, :created_at, :updated_at

  def document_count
    object.documents.count
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
