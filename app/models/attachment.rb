class Attachment < ApplicationRecord
  MAX_FILE_SIZE = 50.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp image/svg+xml
    application/pdf
    text/plain text/markdown text/csv text/html text/css text/javascript
    application/json application/zip application/gzip
  ].freeze

  belongs_to :document, counter_cache: :attachments_count
  has_one_attached :file
  has_one_attached :thumbnail

  validates :filename, presence: true, length: { maximum: 255 }
  validates :content_type, presence: true, inclusion: { in: ALLOWED_CONTENT_TYPES, message: "is not allowed" }
  validates :file_size, presence: true, numericality: { less_than_or_equal_to: MAX_FILE_SIZE }
  validate :file_present

  enum :preview_state, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }, prefix: :preview

  scope :by_type, ->(type) { where(content_type: type) }
  scope :images, -> { where("content_type LIKE ?", "image/%") }
  scope :documents, -> { where("content_type LIKE ? OR content_type LIKE ?", "application/pdf", "text/%") }
  scope :recent, -> { order(created_at: :desc) }

  def image?
    content_type.start_with?("image/")
  end

  def pdf?
    content_type == "application/pdf"
  end

  def text?
    content_type.start_with?("text/")
  end

  def human_file_size
    return "0 B" if file_size.zero?

    units = %w[B KB MB GB TB]
    exp = (Math.log(file_size) / Math.log(1024)).to_i
    exp = units.length - 1 if exp >= units.length

    "#{file_size.to_f / 1024**exp} #{units[exp]}"
  end

  def file_extension
    File.extname(filename).delete(".").downcase
  end

  private

  def file_present
    errors.add(:file, "must be attached") unless file.attached?
  end
end
