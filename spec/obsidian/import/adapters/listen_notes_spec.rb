# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::ListenNotes do
  subject(:adapter) { described_class.new }

  let(:search_result) do
    {
      "id" => "abc123",
      "title_original" => "The Bike Shed",
      "description_original" => "A weekly podcast about Ruby and web development.",
      "publisher_original" => "thoughtbot",
      "website" => "https://bikeshed.thoughtbot.com",
      "listennotes_url" => "https://www.listennotes.com/c/abc123/",
      "image" => "https://example.com/cover.jpg",
      "total_episodes" => 42
    }
  end

  let(:podcast_json) do
    {
      "id" => "abc123",
      "title" => "The Bike Shed",
      "description" => "A weekly podcast about Ruby and web development.",
      "publisher" => "thoughtbot",
      "website" => "https://bikeshed.thoughtbot.com",
      "listennotes_url" => "https://www.listennotes.com/c/abc123/",
      "image" => "https://example.com/cover.jpg",
      "total_episodes" => 42
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["podcast"])
      expect(adapter.source).to eq("Listen Notes")
    end
  end

  describe "#search" do
    before { ENV["LISTEN_NOTES_API_KEY"] = "testkey" }

    it "normalizes each result and sends the API key header" do
      stub_request(:get, "https://listen-api.listennotes.com/api/v2/search")
        .with(query: {"q" => "bike shed", "type" => "podcast"}, headers: {"X-ListenAPI-Key" => "testkey"})
        .to_return(status: 200, body: JSON.generate({"results" => [search_result]}))

      results = adapter.search(query: "bike shed")
      resource = results.first
      expect(resource).to be_a(Obsidian::Import::Resource)
      expect(resource.type).to eq("podcast")
      expect(resource.subtype).to be_nil
      expect(resource.title).to eq("The Bike Shed")
      expect(resource.source_id).to eq("abc123")
      expect(resource.source_url).to eq("https://www.listennotes.com/c/abc123/")
      expect(resource.description).to eq("A weekly podcast about Ruby and web development.")
      expect(resource.metadata["publisher"]).to eq("thoughtbot")
      expect(resource.metadata["website"]).to eq("https://bikeshed.thoughtbot.com")
      expect(resource.metadata["total_episodes"]).to eq(42)
      expect(resource.metadata["image_url"]).to eq("https://example.com/cover.jpg")
      expect(resource.tags).to eq(["podcast"])
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://listen-api.listennotes.com/api/v2/search")
        .with(query: {"q" => "zzz", "type" => "podcast"})
        .to_return(status: 200, body: JSON.generate({"results" => []}))
      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    before { ENV["LISTEN_NOTES_API_KEY"] = "testkey" }

    it "fetches and normalizes a single podcast" do
      stub_request(:get, "https://listen-api.listennotes.com/api/v2/podcasts/abc123")
        .with(headers: {"X-ListenAPI-Key" => "testkey"})
        .to_return(status: 200, body: JSON.generate(podcast_json))

      resource = adapter.lookup(id: "abc123")
      expect(resource.type).to eq("podcast")
      expect(resource.title).to eq("The Bike Shed")
      expect(resource.source_id).to eq("abc123")
      expect(resource.description).to eq("A weekly podcast about Ruby and web development.")
      expect(resource.source_url).to eq("https://www.listennotes.com/c/abc123/")
      expect(resource.metadata["publisher"]).to eq("thoughtbot")
      expect(resource.tags).to eq(["podcast"])
    end

    it "raises NotFoundError for a missing podcast" do
      stub_request(:get, "https://listen-api.listennotes.com/api/v2/podcasts/nope")
        .with(headers: {"X-ListenAPI-Key" => "testkey"})
        .to_return(status: 404, body: "")
      expect { adapter.lookup(id: "nope") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "without a configured credential" do
    it "raises MissingCredentialError on first use" do
      expect { adapter.search(query: "bike shed") }
        .to raise_error(Obsidian::Import::MissingCredentialError)
    end
  end
end
