class Document < ApplicationRecord
  include PgSearch::Model

  belongs_to :workspace
  belongs_to :folder, optional: true
  has_many :document_tags, dependent: :destroy
  has_many :tags, through: :document_tags
  has_many :attachments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_folder, ->(folder_id) { where(folder_id: folder_id) }
  scope :by_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name.downcase }) }

  # Full-text search scope using pg_search
  pg_search_scope :full_text_search,
    against: { title: "A", body: "B" },
    associated_against: {
      tags: { name: "C" }
    },
    using: {
      tsearch: {
        dictionary: "english",
        tsvector_column: "search_vector"
      },
      trigram: {
        threshold: 0.3,
        word_similarity: true
      }
    },
    ranked_by: ":tsearch + :trigram"

  # Scope: search within user's active documents
  scope :search_for_user, ->(query, user) {
    full_text_search(query)
      .joins(:workspace)
      .where(workspaces: { user_id: user.id })
      .active
  }

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

  def image_attachments
    attachments.images
  end

  def file_attachments
    attachments.where.not(id: attachments.images.select(:id))
  end

  def attachments_size_sum
    attachments.sum(:file_size)
  end
end
