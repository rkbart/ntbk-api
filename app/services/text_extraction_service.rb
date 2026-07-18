class TextExtractionService
  def initialize(attachment)
    @attachment = attachment
    @file = attachment.file
  end

  # Extract text content from the attachment
  def extract
    return nil unless @file.attached?

    case @attachment.content_type
    when "text/plain", "text/markdown", "text/csv", "text/html", "text/css", "text/javascript"
      extract_from_text
    when "application/pdf"
      extract_from_pdf
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_from_docx
    when "application/json"
      extract_from_json
    else
      nil
    end
  end

  # Extract tags from document content
  # Supports formats:
  # - YAML frontmatter: tags:\n  - tag1\n  - tag2
  # - Inline: Tags: tag1, tag2, tag3
  # - Array: tags: [tag1, tag2]
  def extract_tags(content)
    return [] if content.blank?

    tags = []

    # Pattern 1: YAML frontmatter tags
    # tags:\n  - tag1\n  - tag2
    if content =~ /^tags:\s*\n((?:\s*-\s*.+\n?)+)/mi
      yaml_tags = $1.scan(/-\s*(.+)/).flatten
      tags.concat(yaml_tags.map(&:strip).reject(&:blank?))
    end

    # Pattern 2: Inline tags
    # Tags: tag1, tag2, tag3
    # tags: tag1, tag2, tag3
    if content =~ /^(?:tags|Tags):\s*(.+)$/mi
      inline_tags = $1.split(",").map(&:strip).reject(&:blank?)
      tags.concat(inline_tags)
    end

    # Pattern 3: Array tags
    # tags: [tag1, tag2]
    if content =~ /^tags:\s*\[(.+)\]/mi
      array_tags = $1.split(",").map(&:strip).reject(&:blank?)
      tags.concat(array_tags)
    end

    tags.uniq.map(&:downcase)
  end

  # Remove tags section from content
  def remove_tags_from_content(content)
    return content if content.blank?

    cleaned = content.dup

    # Remove YAML frontmatter tags block
    # tags:\n  - tag1\n  - tag2
    cleaned.gsub!(/^tags:\s*\n(?:\s*-\s*.+\n?)+/mi, "")

    # Remove inline tags
    # Tags: tag1, tag2, tag3
    cleaned.gsub!(/^(?:tags|Tags):\s*.+$/mi, "")

    # Remove array tags
    # tags: [tag1, tag2]
    cleaned.gsub!(/^tags:\s*\[.+\]/mi, "")

    # Clean up multiple blank lines
    cleaned.gsub!(/\n{3,}/, "\n\n")

    cleaned.strip
  end

  private

  def extract_from_text
    @file.download
  rescue => e
    Rails.logger.error "Failed to extract text: #{e.message}"
    nil
  end

  def extract_from_pdf
    require "pdf/reader"

    text_parts = []
    @file.download do |pdf_content|
      reader = PDF::Reader.new(StringIO.new(pdf_content))
      reader.pages.each do |page|
        text_parts << page.text
      end
    end

    text_parts.join("\n\n").strip
  rescue => e
    Rails.logger.error "Failed to extract PDF text: #{e.message}"
    nil
  end

  def extract_from_docx
    require "docx"

    temp_file = Tempfile.new(["docx", ".docx"])
    temp_file.binmode

    @file.download do |content|
      temp_file.write(content)
    end
    temp_file.rewind

    doc = Docx::Document.open(temp_file.path)
    text = doc.paragraphs.map(&:to_s).join("\n")

    temp_file.close
    temp_file.unlink

    text.strip
  rescue => e
    Rails.logger.error "Failed to extract DOCX text: #{e.message}"
    nil
  end

  def extract_from_json
    content = @file.download
    parsed = JSON.parse(content)
    JSON.pretty_generate(parsed)
  rescue => e
    Rails.logger.error "Failed to extract JSON text: #{e.message}"
    nil
  end
end
