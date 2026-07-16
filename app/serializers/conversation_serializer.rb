class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :title, :last_message_at, :message_count, :created_at

  def last_message_at
    object.last_message_at&.iso8601
  end

  def created_at
    object.created_at&.iso8601
  end

  def message_count
    object.message_count
  end
end
