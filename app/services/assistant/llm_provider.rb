module Assistant
  # Template method: subclasses describe one provider's request and response shape; this class owns transport and errors.
  class LlmProvider
    class Error < StandardError; end

    Completion = Data.define(:text, :prompt_tokens, :completion_tokens)
    PROVIDERS = { "open_router" => "Assistant::OpenRouterProvider" }.freeze

    def self.build(config = Rails.configuration.x.assistant) = PROVIDERS.fetch(config[:provider].to_s).constantize.new(config)

    def initialize(config)
      @config = config
    end

    def complete(system:, message:)
      request_headers = headers
      response = post(endpoint, request_headers, build_payload(system:, message:))
      Completion.new(text: extract_text(response), **extract_usage(response))
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError => e
      raise Error, "Provider request failed (#{e.class.name})"
    end

    private

    attr_reader :config

    def endpoint = raise(NotImplementedError)
    def headers = raise(NotImplementedError)
    def build_payload(system:, message:) = raise(NotImplementedError)
    def extract_text(response) = raise(NotImplementedError)
    def extract_usage(response) = raise(NotImplementedError)

    def post(uri, request_headers, payload)
      timeout = config[:timeout_seconds]
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: timeout, read_timeout: timeout) do |http|
        http.post(uri.path, payload.to_json, request_headers)
      end
      raise Error, "Provider responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
