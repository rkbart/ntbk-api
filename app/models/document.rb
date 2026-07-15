class Document < ApplicationRecord
  belongs_to :workspace
  belongs_to :folder, optional: true
  has_many :document_tags, dependent: :destroy
  has_many :tags, through: :document_tags

  validates :title, presence: true, length: { maximum: 255 }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_folder, ->(folder_id) { where(folder_id: folder_id) }
  scope :by_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name.downcase }) }

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def body_preview(length = 200)
    return "" if body.blank?
    body.truncate(length, separator: " ")
  end
end
