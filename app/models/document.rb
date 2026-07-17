class Document < ApplicationRecord
  include PgSearch::Model

  belongs_to :workspace
  belongs_to :folder, optional: true
  has_many :document_tags, dependent: :destroy
  has_many :tags, through: :document_tags
  has_many :attachments, dependent: :destroy

  # pgvector support (optional - requires pgvector extension)
  begin
    has_neighbors :embedding
  rescue => e
    # pgvector not available, embedding features will be disabled
  end

  validates :title, presence: true, length: { maximum: 255 }

  # Add after_save callback for auto-embedding generation
  after_save :generate_embedding_if_needed

  private

  def generate_embedding_if_needed
    # Only generate embedding if embedding column exists and content changed
    return unless self.class.column_names.include?('embedding')
    return unless saved_change_to_title? || saved_change_to_body?
    return if embedding.present? && !saved_change_to_body?
    
    # Enqueue background job for embedding generation
    DocumentEmbeddingJob.perform_later(self.id) if persisted?
  end


  def needs_summary?
    summary.nil? || (summary_generated_at.present? && updated_at > summary_generated_at)
  end

  def embedding_text
    # Combine title + body for embedding, truncated to fit context
    text = [ title, body ].compact.join("\n\n")
    text.truncate(2000, separator: " ")
  end

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
