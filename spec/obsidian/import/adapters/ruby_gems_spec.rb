# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::RubyGems do
  subject(:adapter) { described_class.new }

  let(:gem_json) do
    {
      "name" => "view_component",
      "info" => "Reusable view components for Rails.",
      "version" => "4.0.0",
      "downloads" => 12_345_678,
      "authors" => "Joel Hawksley, GitHub",
      "project_uri" => "https://rubygems.org/gems/view_component",
      "homepage_uri" => "https://viewcomponent.org",
      "source_code_uri" => "https://github.com/ViewComponent/view_component",
      "licenses" => ["MIT"]
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["gem"])
      expect(adapter.source).to eq("RubyGems")
    end
  end

  describe "#search" do
    it "normalizes each result" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "view_component"})
        .to_return(status: 200, body: JSON.generate([gem_json]))

      results = adapter.search(query: "view_component")
      expect(results.map(&:title)).to eq(["view_component"])
      expect(results.first).to be_a(Obsidian::Import::Resource)
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "zzz"}).to_return(status: 200, body: "[]")
      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a single gem" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/view_component.json")
        .to_return(status: 200, body: JSON.generate(gem_json))

      resource = adapter.lookup(id: "view_component")
      expect(resource.type).to eq("gem")
      expect(resource.subtype).to eq("gem")
      expect(resource.source_id).to eq("view_component")
      expect(resource.description).to eq("Reusable view components for Rails.")
      expect(resource.source_url).to eq("https://rubygems.org/gems/view_component")
      expect(resource.metadata["version"]).to eq("4.0.0")
      expect(resource.metadata["downloads"]).to eq(12_345_678)
      expect(resource.metadata["authors"]).to eq(["Joel Hawksley", "GitHub"])
      expect(resource.metadata["github_url"]).to eq("https://github.com/ViewComponent/view_component")
      expect(resource.tags).to eq(["gem"])
    end

    it "raises NotFoundError for a missing gem" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/nope.json").to_return(status: 404, body: "")
      expect { adapter.lookup(id: "nope") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#normalize" do
    it "falls back to a constructed source_url and empty authors" do
      resource = adapter.normalize(record: {"name" => "bare"})
      expect(resource.source_url).to eq("https://rubygems.org/gems/bare")
      expect(resource.metadata).not_to have_key("authors")
    end
  end
end
