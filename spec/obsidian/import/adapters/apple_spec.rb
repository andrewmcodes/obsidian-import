# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::Apple do
  subject(:adapter) { described_class.new }

  let(:app_json) do
    {
      "trackId" => 123,
      "trackName" => "Raycast",
      "description" => "A blazingly fast, totally extendable launcher.",
      "sellerName" => "Raycast Technologies Ltd.",
      "trackViewUrl" => "https://apps.apple.com/us/app/raycast/id123",
      "artworkUrl512" => "https://example.com/512.png",
      "version" => "1.0",
      "primaryGenreName" => "Productivity",
      "bundleId" => "com.raycast.macos",
      "averageUserRating" => 4.8,
      "formattedPrice" => "Free"
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["app"])
      expect(adapter.source).to eq("Apple App Store")
    end
  end

  describe "#search" do
    it "normalizes each result" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: {"term" => "raycast", "entity" => "software", "limit" => "10", "country" => "US"})
        .to_return(status: 200, body: JSON.generate({"resultCount" => 1, "results" => [app_json]}))

      results = adapter.search(query: "raycast")
      expect(results.map(&:title)).to eq(["Raycast"])
      expect(results.first).to be_a(Obsidian::Import::Resource)
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://itunes.apple.com/search")
        .with(query: {"term" => "zzz", "entity" => "software", "limit" => "10", "country" => "US"})
        .to_return(status: 200, body: JSON.generate({"resultCount" => 0, "results" => []}))

      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a single app" do
      stub_request(:get, "https://itunes.apple.com/lookup")
        .with(query: {"id" => "123"})
        .to_return(status: 200, body: JSON.generate({"resultCount" => 1, "results" => [app_json]}))

      resource = adapter.lookup(id: "123")
      expect(resource.type).to eq("app")
      expect(resource.title).to eq("Raycast")
      expect(resource.source_id).to eq("123")
    end

    it "raises NotFoundError for a zero-result lookup" do
      stub_request(:get, "https://itunes.apple.com/lookup")
        .with(query: {"id" => "999"})
        .to_return(status: 200, body: JSON.generate({"resultCount" => 0, "results" => []}))

      expect { adapter.lookup(id: "999") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#normalize" do
    it "maps the metadata fields and coerces trackId to a string source_id" do
      resource = adapter.normalize(record: app_json)

      expect(resource.subtype).to eq("app")
      expect(resource.source_id).to eq("123")
      expect(resource.source_url).to eq("https://apps.apple.com/us/app/raycast/id123")
      expect(resource.description).to eq("A blazingly fast, totally extendable launcher.")
      expect(resource.metadata["seller"]).to eq("Raycast Technologies Ltd.")
      expect(resource.metadata["version"]).to eq("1.0")
      expect(resource.metadata["genre"]).to eq("Productivity")
      expect(resource.metadata["bundle_id"]).to eq("com.raycast.macos")
      expect(resource.metadata["image_url"]).to eq("https://example.com/512.png")
      expect(resource.metadata["rating"]).to eq(4.8)
      expect(resource.metadata["price"]).to eq("Free")
      expect(resource.tags).to eq(["app"])
    end
  end
end
