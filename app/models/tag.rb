class Tag < ApplicationRecord
  belongs_to :user
  has_many :document_tags, dependent: :destroy
  has_many :documents, through: :document_tags

  validates :name, presence: true, length: { maximum: 50 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :normalize_name

  def document_count
    documents.count
  end

  private

  def normalize_name
    self.name = name.downcase.strip if name.present?
  end
end
