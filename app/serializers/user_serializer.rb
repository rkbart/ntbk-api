class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :created_at, :updated_at

  # Don't expose these in production
  # attribute :sign_in_count, if: :admin?

  def created_at
    object.created_at&.iso8601
  end

  def updated_at
    object.updated_at&.iso8601
  end
end
