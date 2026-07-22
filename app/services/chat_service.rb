class ChatService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful AI assistant for a notebook application.

    IMPORTANT RULES:
    1. ONLY answer based on the documents provided to you in the context below.
    2. Do NOT make up or hallucinate document names, content, or information.
    3. If no documents are provided or the context is empty, clearly state that you don't have access to any relevant documents.
    4. When documents ARE provided, base your answers ONLY on the content of those specific documents.
    5. If a question cannot be answered from the provided documents, say so clearly.
    6. Never fabricate document titles, names, or content that wasn't provided to you.
    7. When citing information, mention which document it came from.

    Be concise and helpful. Use markdown formatting when appropriate.
  PROMPT

  def initialize(conversation, provider: nil)
    @conversation = conversation
    @client = LlmClientFactory.create(provider)
    @embedding_service = EmbeddingService.new
  end

  def send_message(content, document_ids: [], workspace_id: nil)
    user_message = @conversation.messages.create!(
      role: "user",
      content: content,
      document_references: document_ids
    )

    messages = build_messages(content, document_ids, workspace_id)
    response_content = @client.chat(messages, temperature: 0.7, max_tokens: 4096)

    if response_content.blank?
      response_content = "I'm sorry, I couldn't generate a response. Please try again."
    end

    assistant_message = @conversation.messages.create!(
      role: "assistant",
      content: response_content
    )

    @conversation.update!(last_message_at: Time.current)
    assistant_message
  end

  def send_message_stream(content, document_ids: [], workspace_id: nil, &block)
    user_message = @conversation.messages.create!(
      role: "user",
      content: content,
      document_references: document_ids
    )

    messages = build_messages(content, document_ids, workspace_id)
    full_response = ""

    @client.chat_stream(messages, { temperature: 0.7, max_tokens: 4096 }) do |chunk|
      full_response += chunk
      yield chunk if block_given?
    end

    if full_response.blank?
      full_response = "I'm sorry, I couldn't generate a response. Please try again."
    end

    assistant_message = @conversation.messages.create!(
      role: "assistant",
      content: full_response
    )

    @conversation.update!(last_message_at: Time.current)
    assistant_message
  end

  private

  def build_messages(content, document_ids, workspace_id)
    messages = [ { role: "system", content: SYSTEM_PROMPT } ]

    relevant_docs = find_relevant_documents(content, document_ids, workspace_id)

    if relevant_docs.any?
      document_context = format_documents_for_context(relevant_docs)
      messages << { role: "system", content: "Here are the most relevant documents for answering this question. Answer ONLY based on these documents:\n\n#{document_context}" }
    else
      messages << { role: "system", content: "No relevant documents were found for this question. You cannot answer questions about specific documents without being provided with them. Tell the user that no relevant documents were found." }
    end

    # Add user's question
    messages << { role: "user", content: content }

    messages
  end

  def find_relevant_documents(query, document_ids, workspace_id)
    if document_ids.present?
      return Document.where(id: document_ids).active.to_a
    end

    if workspace_id.present?
      # Try semantic search first (embeddings)
      begin
        workspace = Workspace.find(workspace_id)
        results = @embedding_service.search(query, workspace: workspace, limit: 10, threshold: 0.5)
        return results if results.any?
      rescue => e
        Rails.logger.warn "Semantic search failed: #{e.message}"
      end

      # Fallback: full-text search on title, body, and extracted attachment text
      documents = Document.where(workspace_id: workspace_id).active
        .left_joins(:attachments)
        .where(
          "documents.title ILIKE :q OR documents.body ILIKE :q OR attachments.metadata::text ILIKE :q",
          q: "%#{query}%"
        )
        .distinct
        .limit(10)
        .to_a

      return documents if documents.any?

      # Last resort: return all active documents in the workspace (max 10)
      return Document.where(workspace_id: workspace_id).active.limit(10).to_a
    end

    []
  end

  def format_documents_for_context(documents)
    documents.map do |doc|
      <<~DOC
        Document: #{doc.title}
        ID: #{doc.id}
        ---
        #{doc.body&.truncate(2000) || "(No content)"}
        ---
      DOC
    end.join("\n\n")
  end
end
