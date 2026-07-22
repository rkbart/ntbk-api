class SearchResultSerializer < ActiveModel::Serializer
  attributes :id, :title, :body_preview, :workspace_id, :folder_id,
             :archived_at, :created_at, :updated_at

  has_one :folder
  has_many :tags

  def body_preview
    object.body.present? ? object.body.truncate(200) : nil
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
