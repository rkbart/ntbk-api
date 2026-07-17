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
