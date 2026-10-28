module Assistant
  class OpenRouterProvider < LlmProvider
    private

    def endpoint = URI("#{config[:base_url]}/chat/completions")

    def headers
      api_key = Rails.application.credentials.dig(:openrouter, :api_key)
      raise Error, "Provider API key is not configured" if api_key.blank?

      { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json", "X-Title" => "Incubyte HR" }
    end

    def build_payload(system:, message:)
      { model: config[:model], temperature: config[:temperature], max_tokens: config[:max_tokens],
        messages: [ { role: "system", content: system }, { role: "user", content: message } ],
        **(config[:json_response] ? { response_format: { type: "json_object" } } : {}) }
    end

    def extract_text(response)
      response.dig("choices", 0, "message", "content").presence || raise(Error, "Provider returned no completion")
    end

    def extract_usage(response)
      { prompt_tokens: response.dig("usage", "prompt_tokens").to_i, completion_tokens: response.dig("usage", "completion_tokens").to_i }
    end
  end
end
