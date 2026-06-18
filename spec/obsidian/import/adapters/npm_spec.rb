# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::Npm do
  subject(:adapter) { described_class.new }

  let(:search_json) do
    {
      "objects" => [
        {
          "package" => {
            "name" => "react",
            "description" => "React is a JavaScript library for building user interfaces.",
            "version" => "18.2.0",
            "keywords" => ["react", "ui"],
            "links" => {
              "npm" => "https://www.npmjs.com/package/react",
              "homepage" => "https://reactjs.org/",
              "repository" => "https://github.com/facebook/react"
            },
            "publisher" => {"username" => "fb"}
          }
        }
      ]
    }
  end

  let(:registry_json) do
    {
      "name" => "react",
      "description" => "React is a JavaScript library for building user interfaces.",
      "dist-tags" => {"latest" => "18.2.0"},
      "homepage" => "https://reactjs.org/",
      "repository" => {
        "type" => "git",
        "url" => "git+https://github.com/facebook/react.git"
      },
      "keywords" => ["react", "ui"],
      "author" => {"name" => "Meta Open Source"},
      "license" => "MIT"
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["npm_package"])
      expect(adapter.source).to eq("npm")
    end
  end

  describe "#search" do
    it "normalizes each nested package object" do
      stub_request(:get, "https://registry.npmjs.org/-/v1/search")
        .with(query: {"text" => "react", "size" => "10"})
        .to_return(status: 200, body: JSON.generate(search_json))

      results = adapter.search(query: "react")
      expect(results.map(&:title)).to eq(["react"])
      expect(results.first).to be_a(Obsidian::Import::Resource)
      expect(results.first.source_url).to eq("https://www.npmjs.com/package/react")
      expect(results.first.metadata["homepage_url"]).to eq("https://reactjs.org/")
      expect(results.first.metadata["github_url"]).to eq("https://github.com/facebook/react")
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://registry.npmjs.org/-/v1/search")
        .with(query: {"text" => "zzz", "size" => "10"})
        .to_return(status: 200, body: JSON.generate({"objects" => []}))

      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a single package using dist-tags.latest" do
      stub_request(:get, "https://registry.npmjs.org/react")
        .to_return(status: 200, body: JSON.generate(registry_json))

      resource = adapter.lookup(id: "react")
      expect(resource.type).to eq("npm_package")
      expect(resource.subtype).to eq("npm")
      expect(resource.source_id).to eq("react")
      expect(resource.source_url).to eq("https://www.npmjs.com/package/react")
      expect(resource.description).to eq("React is a JavaScript library for building user interfaces.")
      expect(resource.metadata["version"]).to eq("18.2.0")
      expect(resource.metadata["homepage_url"]).to eq("https://reactjs.org/")
      expect(resource.metadata["github_url"]).to eq("https://github.com/facebook/react")
      expect(resource.metadata["license"]).to eq("MIT")
      expect(resource.metadata["keywords"]).to eq(["react", "ui"])
      expect(resource.metadata["author"]).to eq("Meta Open Source")
      expect(resource.tags).to eq(["npm"])
    end

    it "raises NotFoundError for a missing package" do
      stub_request(:get, "https://registry.npmjs.org/nope")
        .to_return(status: 404, body: "")

      expect { adapter.lookup(id: "nope") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#normalize" do
    it "handles a String author" do
      resource = adapter.normalize(record: {"name" => "left-pad", "author" => "azer"})
      expect(resource.metadata["author"]).to eq("azer")
    end

    it "handles a Hash author" do
      resource = adapter.normalize(record: {"name" => "react", "author" => {"name" => "Meta Open Source"}})
      expect(resource.metadata["author"]).to eq("Meta Open Source")
    end

    it "cleans up a git+...git repository url" do
      resource = adapter.normalize(
        record: {
          "name" => "react",
          "repository" => {"url" => "git+https://github.com/facebook/react.git"}
        }
      )
      expect(resource.metadata["github_url"]).to eq("https://github.com/facebook/react")
    end

    it "falls back to the search version and links shapes" do
      resource = adapter.normalize(
        record: {
          "name" => "bare",
          "version" => "1.2.3",
          "links" => {"homepage" => "https://example.com", "repository" => "https://github.com/x/y"}
        }
      )
      expect(resource.metadata["version"]).to eq("1.2.3")
      expect(resource.metadata["homepage_url"]).to eq("https://example.com")
      expect(resource.metadata["github_url"]).to eq("https://github.com/x/y")
    end
  end
end
