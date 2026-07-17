class Attachment < ApplicationRecord
  belongs_to :document, counter_cache: :attachments_count

  has_one_attached :file
  has_one_attached :thumbnail

  MAX_FILE_SIZE = 50.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/gif
    image/webp
    image/svg+xml
    application/pdf
    text/plain
    text/markdown
    text/csv
    text/html
    text/css
    text/javascript
    application/json
    application/zip
    application/gzip
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ].freeze

  validates :filename, presence: true, length: { maximum: 255 }
  validates :content_type, presence: true, inclusion: { in: ALLOWED_CONTENT_TYPES }
  validates :file_size, presence: true, numericality: { less_than_or_equal_to: MAX_FILE_SIZE }
  validate :file_present

  enum :preview_state, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }, default: "pending"

  scope :by_type, ->(content_type) { where(content_type: content_type) }
  scope :images, -> { where(content_type: %w[image/jpeg image/png image/gif image/webp]) }
  scope :documents, -> { where(content_type: %w[application/pdf text/plain text/markdown application/vnd.openxmlformats-officedocument.wordprocessingml.document]) }
  scope :recent, -> { order(created_at: :desc) }

  after_create :enqueue_text_extraction

  def image?
    content_type&.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end

  def text?
    content_type&.start_with?("text/")
  end

  def docx?
    content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  end

  def human_file_size
    return "0 B" unless file_size

    units = %w[B KB MB GB]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def file_extension
    File.extname(filename).delete(".")
  end

  def extracted_text
    metadata&.dig("text_content")
  end

  def text_extracted?
    metadata&.dig("text_extracted") == true
  end

  private

  def file_present
    errors.add(:file, "must be attached") unless file.attached?
  end

  def enqueue_text_extraction
    Attachments::TextExtractionJob.perform_later(id)
  end
end
