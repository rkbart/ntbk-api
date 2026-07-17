class WorkspaceSummaryService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful AI assistant that creates summaries of workspaces.

    Given the documents in a workspace, create a comprehensive summary that:
    1. Lists all documents and their main topics
    2. Identifies common themes across documents
    3. Provides a brief overview of each document's content
    4. Highlights key information and relationships between documents

    Be concise but thorough. Use markdown formatting.
  PROMPT

  def initialize(workspace, provider: nil)
    @workspace = workspace
    @client = LlmClientFactory.create(provider)
  end

  def generate_summary
    documents = @workspace.documents.active.includes(:tags, :attachments)

    return "No documents in this workspace to summarize." if documents.empty?

    # Build context from all documents
    context = build_documents_context(documents)

    messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: "Please summarize the following workspace documents:\n\n#{context}" }
    ]

    @client.chat(messages, temperature: 0.3, max_tokens: 2048)
  end

  private

  def build_documents_context(documents)
    documents.map do |doc|
      content = [ doc.title ]

      if doc.body.present?
        content << doc.body.truncate(1000)
      end

      if doc.attachments.any?
        attachment_texts = doc.attachments.filter_map do |att|
          att.metadata&.dig("text_content")&.truncate(500)
        end
        content << "Attachments: #{attachment_texts.join(', ')}" if attachment_texts.any?
      end

      if doc.tags.any?
        content << "Tags: #{doc.tags.map(&:name).join(', ')}"
      end

      content.join("\n")
    end.join("\n\n---\n\n")
  end
end
