# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::VSCode do
  subject(:adapter) { described_class.new }

  let(:endpoint) { "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" }

  let(:extension) do
    {
      "publisher" => {"publisherName" => "esbenp", "displayName" => "Prettier"},
      "extensionName" => "prettier-vscode",
      "displayName" => "Prettier - Code formatter",
      "shortDescription" => "Code formatter using prettier",
      "versions" => [{
        "version" => "10.1.0",
        "files" => [
          {"assetType" => "Microsoft.VisualStudio.Services.Icons.Default", "source" => "https://cdn/icon.png"},
          {"assetType" => "Microsoft.VisualStudio.Code.Manifest", "source" => "https://cdn/manifest"}
        ]
      }],
      "statistics" => [
        {"statisticName" => "install", "value" => 42_000_000},
        {"statisticName" => "averagerating", "value" => 4.5}
      ],
      "categories" => ["Formatters"],
      "tags" => ["javascript", "formatter"]
    }
  end

  def response_with(*extensions)
    JSON.generate("results" => [{"extensions" => extensions}])
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["vscode_extension"])
      expect(adapter.source).to eq("Visual Studio Marketplace")
    end
  end

  describe "#search" do
    it "posts a VS Code-targeted search query and normalizes results" do
      stub_request(:post, endpoint).to_return(status: 200, body: response_with(extension))

      results = adapter.search(query: "prettier")
      expect(results.map(&:title)).to eq(["Prettier - Code formatter"])
      expect(results.first).to be_a(Obsidian::Import::Resource)

      expect(
        a_request(:post, endpoint).with { |req|
          criteria = JSON.parse(req.body).dig("filters", 0, "criteria")
          criteria.include?({"filterType" => 8, "value" => "Microsoft.VisualStudio.Code"}) &&
            criteria.include?({"filterType" => 10, "value" => "prettier"})
        }
      ).to have_been_made
    end

    it "tolerates an empty result set" do
      stub_request(:post, endpoint).to_return(status: 200, body: response_with)
      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "looks up by publisher.name and normalizes the extension" do
      stub_request(:post, endpoint)
        .with { |req| JSON.parse(req.body).dig("filters", 0, "criteria").include?({"filterType" => 7, "value" => "esbenp.prettier-vscode"}) }
        .to_return(status: 200, body: response_with(extension))

      resource = adapter.lookup(id: "esbenp.prettier-vscode")
      expect(resource.type).to eq("vscode_extension")
      expect(resource.subtype).to eq("extension")
      expect(resource.title).to eq("Prettier - Code formatter")
      expect(resource.source_id).to eq("esbenp.prettier-vscode")
      expect(resource.source_url).to eq("https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode")
      expect(resource.description).to eq("Code formatter using prettier")
      expect(resource.metadata["publisher"]).to eq("Prettier")
      expect(resource.metadata["version"]).to eq("10.1.0")
      expect(resource.metadata["installs"]).to eq(42_000_000)
      expect(resource.metadata["rating"]).to eq(4.5)
      expect(resource.metadata["categories"]).to eq(["Formatters"])
      expect(resource.metadata["icon_url"]).to eq("https://cdn/icon.png")
      expect(resource.tags).to eq(["vscode", "extension"])
    end

    it "raises NotFoundError when no extension matches" do
      stub_request(:post, endpoint).to_return(status: 200, body: response_with)
      expect { adapter.lookup(id: "nope.nope") }.to raise_error(Obsidian::Import::NotFoundError, /nope\.nope/)
    end
  end

  describe "#normalize" do
    it "drops missing optional fields without raising" do
      resource = adapter.normalize(record: {"extensionName" => "bare", "publisher" => {"publisherName" => "me"}})
      expect(resource.source_id).to eq("me.bare")
      expect(resource.title).to eq("bare")
      expect(resource.metadata).not_to have_key("version")
      expect(resource.metadata).not_to have_key("installs")
      expect(resource.metadata).not_to have_key("icon_url")
    end
  end
end
