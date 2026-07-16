class FileUploadValidator
  ALLOWED_TYPES = {
    # Images
    'image/jpeg' => { ext: %w[jpg jpeg], max: 10.megabytes },
    'image/png' => { ext: %w[png], max: 10.megabytes },
    'image/gif' => { ext: %w[gif], max: 10.megabytes },
    'image/webp' => { ext: %w[webp], max: 10.megabytes },
    'image/svg+xml' => { ext: %w[svg], max: 1.megabyte },

    # Documents
    'application/pdf' => { ext: %w[pdf], max: 50.megabytes },

    # Text
    'text/plain' => { ext: %w[txt], max: 1.megabyte },
    'text/markdown' => { ext: %w[md markdown], max: 1.megabyte },
    'text/csv' => { ext: %w[csv], max: 5.megabytes },
    'text/html' => { ext: %w[html htm], max: 5.megabytes },
    'text/css' => { ext: %w[css], max: 1.megabyte },
    'text/javascript' => { ext: %w[js], max: 5.megabytes },

    # Code
    'application/json' => { ext: %w[json], max: 5.megabytes },
    'application/xml' => { ext: %w[xml], max: 5.megabytes },
    'application/yaml' => { ext: %w[yaml yml], max: 1.megabyte },

    # Archives
    'application/zip' => { ext: %w[zip], max: 50.megabytes },
    'application/gzip' => { ext: %w[gz], max: 50.megabytes }
  }.freeze

  def self.validate!(file)
    content_type = file.content_type
    extension = File.extname(file.original_filename).delete('.').downcase

    # Check content type is allowed
    unless ALLOWED_TYPES.key?(content_type)
      raise ValidationError, "File type '#{content_type}' is not allowed"
    end

    # Check extension matches content type
    allowed_exts = ALLOWED_TYPES[content_type][:ext]
    unless allowed_exts.include?(extension)
      raise ValidationError, "File extension '#{extension}' does not match content type"
    end

    # Check file size
    max_size = ALLOWED_TYPES[content_type][:max]
    if file.size > max_size
      raise ValidationError, "File exceeds maximum size of #{max_size / 1.megabyte}MB"
    end

    true
  end

  class ValidationError < StandardError; end
end
