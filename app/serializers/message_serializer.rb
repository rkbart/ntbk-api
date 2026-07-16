class MessageSerializer < ActiveModel::Serializer
  attributes :id, :role, :content, :document_references, :created_at

  def created_at
    object.created_at&.iso8601
  end
end
