class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :created_at, :updated_at

  has_many :workspaces

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
