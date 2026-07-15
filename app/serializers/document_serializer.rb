class DocumentSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :folder_id, :archived_at, :created_at, :updated_at

  belongs_to :folder
  has_many :tags

  def archived_at
    object.archived_at&.iso8601
  end

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
