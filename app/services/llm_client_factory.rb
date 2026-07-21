class LlmClientFactory
  def self.create(provider = nil)
    provider ||= ENV.fetch("LLM_PROVIDER", "ollama")

    case provider.downcase
    when "ollama"
        OllamaClient.new
    when "openai"
        OpenaiClient.new
    when "anthropic"
        AnthropicClient.new
    end
  end
end
