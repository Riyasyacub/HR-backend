require "rails_helper"

RSpec.describe Assistant::LlmProvider do
  let(:config) do
    { provider: "open_router", model: "openai/gpt-4o-mini", max_tokens: 400, temperature: 0, timeout_seconds: 15,
      base_url: "https://openrouter.ai/api/v1" }
  end
  let(:http) { instance_double(Net::HTTP) }
  let(:ok_body) { { choices: [ { message: { content: "SELECT 1" } } ], usage: { prompt_tokens: 120, completion_tokens: 8 } }.to_json }

  def stub_response(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:post).and_return(response)
  end

  def http_response(klass, code, body)
    klass.new("1.1", code, "").tap { |response| allow(response).to receive(:body).and_return(body) }
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:openrouter, :api_key).and_return("sk-test-key")
  end

  it "builds the configured provider and rejects an unknown one" do
    expect(described_class.build(config)).to be_a(Assistant::OpenRouterProvider)
    expect { described_class.build(config.merge(provider: "nope")) }.to raise_error(KeyError)
  end

  it "sends the model, settings, messages and key to OpenRouter and returns text and usage" do
    stub_response(http_response(Net::HTTPOK, "200", ok_body))

    completion = described_class.build(config).complete(system: "schema", message: "headcount?")

    expect(completion).to have_attributes(text: "SELECT 1", prompt_tokens: 120, completion_tokens: 8)
    expect(Net::HTTP).to have_received(:start).with("openrouter.ai", 443, use_ssl: true, open_timeout: 15, read_timeout: 15)
    expect(http).to have_received(:post) do |path, body, headers|
      expect(path).to eq("/api/v1/chat/completions")
      expect(JSON.parse(body)).to eq("model" => "openai/gpt-4o-mini", "temperature" => 0, "max_tokens" => 400,
        "messages" => [ { "role" => "system", "content" => "schema" }, { "role" => "user", "content" => "headcount?" } ])
      expect(headers).to include("Authorization" => "Bearer sk-test-key", "Content-Type" => "application/json")
    end
  end

  it "raises a safe error for a failed response, a timeout or a malformed body" do
    provider = described_class.build(config)

    stub_response(http_response(Net::HTTPTooManyRequests, "429", "{}"))
    expect { provider.complete(system: "s", message: "u") }.to raise_error(described_class::Error, "Provider responded with 429")

    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)
    expect { provider.complete(system: "s", message: "u") }.to raise_error(described_class::Error) { |error| expect(error.message).not_to include("sk-test-key") }

    stub_response(http_response(Net::HTTPOK, "200", "{\"choices\":[]}"))
    expect { provider.complete(system: "s", message: "u") }.to raise_error(described_class::Error, "Provider returned no completion")
  end

  it "refuses to call the provider without an API key" do
    allow(Rails.application.credentials).to receive(:dig).with(:openrouter, :api_key).and_return(nil)
    allow(Net::HTTP).to receive(:start)

    expect { described_class.build(config).complete(system: "s", message: "u") }.to raise_error(described_class::Error, "Provider API key is not configured")
    expect(Net::HTTP).not_to have_received(:start)
  end

  it "requires subclasses to implement the provider steps" do
    expect { Class.new(described_class).new(config).complete(system: "s", message: "u") }.to raise_error(NotImplementedError)
  end

  it "asks OpenRouter for a JSON object when configured" do
    stub_response(http_response(Net::HTTPOK, "200", ok_body))

    described_class.build(config.merge(json_response: true)).complete(system: "s", message: "u")

    expect(http).to have_received(:post) { |_path, body, _headers| expect(JSON.parse(body)["response_format"]).to eq("type" => "json_object") }
  end
end
