class ChatService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful AI assistant integrated into a notebook application.
    You can help users understand and work with their documents.
    When referencing documents, mention their titles.
    Be concise and helpful. Use markdown formatting when appropriate.
  PROMPT

  def initialize(conversation)
    @conversation = conversation
    @client = OllamaClient.new
  end

  # Send a message and get response
  def send_message(content, document_ids: [])
    # Save user message
    user_message = @conversation.messages.create!(
      role: "user",
      content: content,
      document_references: document_ids
    )

    # Build context with documents if provided
    messages = build_messages(content, document_ids)

    # Get AI response
    response_content = @client.chat(messages, temperature: 0.7, num_ctx: 4096)

    # Save assistant message
    assistant_message = @conversation.messages.create!(
      role: "assistant",
      content: response_content
    )

    # Update conversation timestamp
    @conversation.update!(last_message_at: Time.current)

    assistant_message
  end

  # Send message with streaming
  def send_message_stream(content, document_ids: [], &block)
    user_message = @conversation.messages.create!(
      role: "user",
      content: content,
      document_references: document_ids
    )

    messages = build_messages(content, document_ids)
    full_response = ""

    @client.chat_stream(messages, { temperature: 0.7, num_ctx: 4096 }) do |chunk|
      full_response += chunk
      yield chunk if block_given?
    end

    assistant_message = @conversation.messages.create!(
      role: "assistant",
      content: full_response
    )

    @conversation.update!(last_message_at: Time.current)
    assistant_message
  end

  private

  def build_messages(content, document_ids)
    messages = [{ role: "system", content: SYSTEM_PROMPT }]

    # Add document context if provided
    if document_ids.present?
      documents = Document.where(id: document_ids).active
      document_context = documents.map { |d| "Document: #{d.title}\n#{d.body&.truncate(2000)}" }.join("\n\n---\n\n")
      messages << { role: "system", content: "Here are the documents for context:\n\n#{document_context}" }
    end

    # Add conversation history (last 10 messages)
    history = @conversation.messages.chronological.last(10)
    history.each do |msg|
      messages << { role: msg.role, content: msg.content }
    end

    messages
  end
end
