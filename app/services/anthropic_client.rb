class AnthropicClient
  BASE_URL = "https://api.anthropic.com/v1"
  API_KEY = ENV.fetch("ANTHROPIC_API_KEY", "")
  CHAT_MODEL = ENV.fetch("ANTHROPIC_CHAT_MODEL", "claude-3-sonnet-20240229")

  def initialize
    @api_key = API_KEY
    raise ArgumentError, "Anthropic API key is required" if @api_key.blank?
  end

  # Generate embedding for text (Anthropic doesn't have embeddings API)
  # This is a placeholder - Anthropic doesn't provide embeddings
  def embed(text)
    Rails.logger.warn "Anthropic does not provide embeddings API. Use OpenAI or Ollama for embeddings."
    nil
  end

  # Generate chat completion (non-streaming)
  def chat(messages, options = {})
    # Convert messages to Anthropic format
    anthropic_messages = messages.map do |msg|
      {
        role: msg[:role] == "system" ? "user" : msg[:role],
        content: msg[:content]
      }
    end

    # Extract system message if present
    system_message = messages.find { |m| m[:role] == "system" }&.dig(:content)

    response = post("/messages", {
      model: CHAT_MODEL,
      max_tokens: options[:max_tokens] || 1000,
      system: system_message,
      messages: anthropic_messages
    })

    response.dig("content", 0, "text")
  rescue => e
    Rails.logger.error "Anthropic chat error: #{e.message}"
    nil
  end

  # Generate chat completion (streaming)
  def chat_stream(messages, options = {}, &block)
    # Convert messages to Anthropic format
    anthropic_messages = messages.map do |msg|
      {
        role: msg[:role] == "system" ? "user" : msg[:role],
        content: msg[:content]
      }
    end

    # Extract system message if present
    system_message = messages.find { |m| m[:role] == "system" }&.dig(:content)

    uri = URI("#{BASE_URL}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 300

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = @api_key
    request["anthropic-version"] = "2023-06-01"
    request["Content-Type"] = "application/json"
    request.body = {
      model: CHAT_MODEL,
      max_tokens: options[:max_tokens] || 1000,
      stream: true,
      system: system_message,
      messages: anthropic_messages
    }.to_json

    http.request(request) do |response|
      response.read_body do |chunk|
        chunk.split("\n").each do |line|
          next if line.strip.empty?
          next unless line.start_with?("data: ")

          data = JSON.parse(line[6..])
          if data["type"] == "content_block_delta"
            content = data.dig("delta", "text")
            yield content if content.present?
          end
        end
      end
    end
  end

  # Check if Anthropic is configured
  def health_check
    @api_key.present?
  end

  private

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = @api_key
    request["anthropic-version"] = "2023-06-01"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
