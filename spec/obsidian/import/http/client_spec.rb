# frozen_string_literal: true

RSpec.describe Obsidian::Import::HTTP::Client do
  subject(:client) do
    described_class.new(base_url: "https://api.example.com", cache: cache, ttl: 100, source: "Example")
  end

  let(:cache) { Obsidian::Import::Cache.new(dir: File.join(ENV["XDG_CACHE_HOME"], "http"), ttl: 100) }

  describe "#get" do
    it "parses a JSON response" do
      stub = stub_request(:get, "https://api.example.com/things")
        .with(query: {"q" => "rails"})
        .to_return(status: 200, body: '{"ok":true}', headers: {"Content-Type" => "application/json"})
      expect(client.get("/things", params: {q: "rails"})).to eq("ok" => true)
      expect(stub).to have_been_requested
    end

    it "caches successful responses (one network call)" do
      stub = stub_request(:get, "https://api.example.com/x").to_return(status: 200, body: "{}")
      client.get("/x")
      client.get("/x")
      expect(stub).to have_been_requested.once
    end

    it "excludes sensitive params from the cache key" do
      stub_request(:get, "https://api.example.com/x").with(query: hash_including("api_key" => "secret"))
        .to_return(status: 200, body: '{"v":1}')
      client.get("/x", params: {api_key: "secret"})
      keys = Dir.glob(File.join(ENV["XDG_CACHE_HOME"], "http", "*.json"))
      expect(keys).not_to be_empty
      expect(File.read(keys.first)).not_to include("secret")
    end

    context "error mapping" do
      {401 => Obsidian::Import::AuthenticationError,
       403 => Obsidian::Import::AuthenticationError,
       404 => Obsidian::Import::NotFoundError,
       429 => Obsidian::Import::RateLimitError,
       500 => Obsidian::Import::ResponseError}.each do |status, error|
        it "maps HTTP #{status} to #{error}" do
          stub_request(:get, "https://api.example.com/x").to_return(status: status, body: "")
          expect { client.get("/x") }.to raise_error(error)
        end
      end

      it "redacts secret-bearing params not on any fixed allowlist" do
        stub_request(:get, "https://api.example.com/x")
          .with(query: hash_including("client_secret" => "alpha", "access_token" => "bravo"))
          .to_return(status: 403, body: "")
        expect { client.get("/x", params: {client_secret: "alpha", access_token: "bravo"}) }
          .to raise_error(Obsidian::Import::AuthenticationError) { |e|
            expect(e.message).not_to include("alpha")
            expect(e.message).not_to include("bravo")
          }
      end

      it "redacts sensitive params from error messages" do
        stub_request(:get, "https://api.example.com/x").with(query: hash_including("api_key" => "secret"))
          .to_return(status: 404, body: "")
        expect { client.get("/x", params: {api_key: "secret"}) }
          .to raise_error(Obsidian::Import::NotFoundError) { |e|
            expect(e.message).to include("[REDACTED]")
            expect(e.message).not_to include("secret")
          }
      end

      it "wraps timeouts in NetworkError" do
        stub_request(:get, "https://api.example.com/x").to_timeout
        expect { client.get("/x") }.to raise_error(Obsidian::Import::NetworkError)
      end

      it "raises ResponseError on malformed JSON" do
        stub_request(:get, "https://api.example.com/x").to_return(status: 200, body: "{not json")
        expect { client.get("/x") }.to raise_error(Obsidian::Import::ResponseError, /malformed/)
      end
    end
  end
end
