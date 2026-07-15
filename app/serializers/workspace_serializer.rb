class WorkspaceSerializer < ActiveModel::Serializer
  attributes :id, :name, :created_at, :updated_at

  has_many :folders
  has_many :documents

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
