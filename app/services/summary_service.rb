class SummaryService
  SUMMARY_PROMPT = <<~PROMPT
    You are a helpful assistant that creates concise summaries of documents.
    Generate a 2-3 sentence summary that captures the key points and main ideas.
    Focus on actionable information and important concepts.
    Do not include headers, bullet points, or formatting - just plain text.
  PROMPT

  def initialize(provider: nil)
    @client = LlmClientFactory.create(provider)
  end

  # Generate summary for a document
  def generate_summary(document)
    # Check if document is a String (shouldn't be)
    if document.is_a?(String)
      Rails.logger.error "SummaryService: ERROR - document is a String, not a Document!"
      Rails.logger.error "SummaryService: document value = #{document.inspect}"
      return nil
    end

    return document.summary if document.respond_to?(:summary) && document.summary.present? && !document.needs_summary?

    content = [ document.title, document.body ].compact.join("\n\n")
    return nil if content.blank?

    messages = [
      { role: "system", content: SUMMARY_PROMPT },
      { role: "user", content: "Please summarize this document:\n\n#{content.truncate(6000)}" }
    ]

    summary = @client.chat(messages, temperature: 0.3, max_tokens: 200)
    document.update!(summary: summary, summary_generated_at: Time.current) if summary.present?

    summary
  end

  # Generate summaries for multiple documents
  def generate_summaries(documents)
    documents.find_each do |document|
      next unless document.respond_to?(:needs_summary?) && document.needs_summary?
      generate_summary(document)
      sleep(0.5)  # Rate limiting
    end
  end
end
