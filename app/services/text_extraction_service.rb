class TextExtractionService
  def initialize(attachment)
    @attachment = attachment
    @file = attachment.file
  end

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

  def extract_tags(content)
    return [] if content.blank?

    tags = []

    if content =~ /\A---\s*\n(.+?)\n---/m
      frontmatter = $1

      # YAML tags block: tags:\n  - tag1\n  - tag2
      if frontmatter =~ /^tags:\s*\n((?:\s+-\s+.+\n?)+)/m
        yaml_block = $1
        yaml_tags = yaml_block.scan(/^\s*-\s+(.+)/).flatten
        tags.concat(yaml_tags.map(&:strip).reject(&:blank?))
      end

      # Inline tags: tags: tag1, tag2
      if frontmatter =~ /^tags:\s*(.+)$/i
        inline_tags = $1.split(",").map(&:strip).reject(&:blank?)
        tags.concat(inline_tags)
      end
    else
      # No frontmatter, check for inline tags in content
      if content =~ /^(?:tags|Tags):\s*(.+)$/mi
        inline_tags = $1.split(",").map(&:strip).reject(&:blank?)
        tags.concat(inline_tags)
      end
    end

    tags.uniq.map(&:downcase)
  end

  def remove_tags_from_content(content)
    return content if content.blank?

    cleaned = content.dup

    if cleaned =~ /\A---\s*\n(.+?)\n---/m
      frontmatter = $1
      body = $'

      # Remove tags from frontmatter
      cleaned_frontmatter = frontmatter.dup
      cleaned_frontmatter.gsub!(/^tags:\s*\n(?:\s*-\s*.+\n?)+/mi, "")
      cleaned_frontmatter.gsub!(/^tags:\s*.+$/mi, "")
      cleaned_frontmatter = cleaned_frontmatter.strip

      if cleaned_frontmatter.blank?
        cleaned = body.strip
      else
        cleaned = "---\n#{cleaned_frontmatter}\n---\n\n#{body.strip}"
      end
    else
      cleaned.gsub!(/^(?:tags|Tags):\s*.+$/mi, "")
    end

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
      reader.pages.each { |page| text_parts << page.text }
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
    @file.download { |content| temp_file.write(content) }
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
