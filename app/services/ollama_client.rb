require "net/http"

class OllamaClient
  BASE_URL = ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
  EMBEDDING_MODEL = ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")
  CHAT_MODEL = ENV.fetch("OLLAMA_CHAT_MODEL", "llama3:8b")

  def initialize
    @base_url = BASE_URL
  end

  # Generate embedding for text
  def embed(text)
    response = post("/api/embed", {
      model: EMBEDDING_MODEL,
      input: text
    })

    response["embeddings"].first
  rescue => e
    Rails.logger.error "Ollama embed error: #{e.message}"
    nil
  end

  # Generate chat completion (non-streaming)
  def chat(messages, options = {})
    model = options.delete(:model) || CHAT_MODEL
    response = post("/api/chat", {
      model: model,
      messages: messages,
      stream: false,
      options: options
    })

    response.dig("message", "content")
  rescue => e
    Rails.logger.error "Ollama chat error: #{e.message}"
    nil
  end

  # Generate chat completion (streaming via HTTP)
  def chat_stream(messages, options = {}, &block)
    uri = URI("#{@base_url}/api/chat")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      model: CHAT_MODEL,
      messages: messages,
      stream: true,
      options: options
    }.to_json

    http.request(request) do |response|
      response.read_body do |chunk|
        chunk.split("\n").each do |line|
          next if line.strip.empty?
          data = JSON.parse(line)
          yield data if block_given?
          return data["response"] if data["done"]
        end
      end
    end
  end

  # Check if Ollama is running
  def health_check
    uri = URI("#{@base_url}/api/tags")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue
    false
  end

  private

  def post(path, body)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 600  # 10 minutes timeout for chat responses
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
