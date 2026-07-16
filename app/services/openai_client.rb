class OpenaiClient
  BASE_URL = "https://api.openai.com/v1"
  API_KEY = ENV.fetch("OPENAI_API_KEY", "")
  EMBEDDING_MODEL = ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
  CHAT_MODEL = ENV.fetch("OPENAI_CHAT_MODEL", "gpt-4")

  def initialize
    @api_key = API_KEY
    raise ArgumentError, "OpenAI API key is required" if @api_key.blank?
  end

  # Generate embedding for text
  def embed(text)
    response = post("/embeddings", {
      model: EMBEDDING_MODEL,
      input: text
    })

    response.dig("data", 0, "embedding")
  rescue => e
    Rails.logger.error "OpenAI embed error: #{e.message}"
    nil
  end

  # Generate chat completion (non-streaming)
  def chat(messages, options = {})
    response = post("/chat/completions", {
      model: CHAT_MODEL,
      messages: messages,
      temperature: options[:temperature] || 0.7,
      max_tokens: options[:max_tokens] || 1000
    })

    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI chat error: #{e.message}"
    nil
  end

  # Generate chat completion (streaming)
  def chat_stream(messages, options = {}, &block)
    uri = URI("#{BASE_URL}/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 300

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: CHAT_MODEL,
      messages: messages,
      stream: true,
      temperature: options[:temperature] || 0.7,
      max_tokens: options[:max_tokens] || 1000
    }.to_json

    http.request(request) do |response|
      response.read_body do |chunk|
        chunk.split("\n").each do |line|
          next if line.strip.empty? || line.strip == "data: [DONE]"
          next unless line.start_with?("data: ")

          data = JSON.parse(line[6..])
          content = data.dig("choices", 0, "delta", "content")
          yield content if content.present?
        end
      end
    end
  end

  # Check if OpenAI is configured
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
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
