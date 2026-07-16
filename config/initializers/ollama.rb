require "ostruct"

# Ollama configuration
Rails.application.config.ollama = OpenStruct.new(
  base_url: ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434"),
  embedding_model: ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text"),
  chat_model: ENV.fetch("OLLAMA_CHAT_MODEL", "llama3:8b"),
  embedding_dimensions: 768,
  timeout: ENV.fetch("OLLAMA_TIMEOUT", 60).to_i
)

# Verify Ollama is running on boot (optional)
if ENV.fetch("OLLAMA_VERIFY_ON_BOOT", "false") == "true"
  Thread.new do
    begin
      client = OllamaClient.new
      if client.health_check
        Rails.logger.info "Ollama is running at #{Rails.application.config.ollama.base_url}"
      else
        Rails.logger.warn "Ollama is not reachable at #{Rails.application.config.ollama.base_url}"
      end
    rescue => e
      Rails.logger.warn "Could not verify Ollama: #{e.message}"
    end
  end
end
