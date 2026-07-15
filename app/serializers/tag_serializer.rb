class TagSerializer < ActiveModel::Serializer
  attributes :id, :name, :document_count, :created_at

  def document_count
    object.document_count
  end

  def created_at
    object.created_at&.iso8601
  end
end
