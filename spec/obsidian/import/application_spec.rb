# frozen_string_literal: true

RSpec.describe Obsidian::Import::Application do
  subject(:app) { described_class.new(config: config) }

  let(:config) { Obsidian::Import::Configuration.load }

  let(:gem_json) do
    {"name" => "rails", "info" => "Web framework.", "version" => "8.0.0",
     "project_uri" => "https://rubygems.org/gems/rails"}
  end

  describe "#types" do
    it "lists every registered type with display metadata" do
      types = app.types
      expect(types.map { |t| t[:type] }).to include("gem", "movie")
      movie = types.find { |t| t[:type] == "movie" }
      expect(movie[:requires_key]).to be(true)
    end
  end

  describe "#search / #lookup" do
    it "delegates to the right adapter" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "rails"}).to_return(status: 200, body: JSON.generate([gem_json]))
      expect(app.search("gem", "rails").first.title).to eq("rails")
    end

    it "looks up by id" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/rails.json")
        .to_return(status: 200, body: JSON.generate(gem_json))
      expect(app.lookup("gem", "rails").source_id).to eq("rails")
    end

    it "raises UnknownTypeError for an unregistered type" do
      expect { app.search("widget", "x") }.to raise_error(Obsidian::Import::UnknownTypeError)
    end
  end

  describe "rendering" do
    let(:resource) do
      Obsidian::Import::Resource.new(type: "gem", subtype: "gem", title: "Rails", source: "RubyGems", source_id: "rails")
    end

    it "renders markdown and frontmatter" do
      expect(app.markdown(resource)).to include("title: Rails", "## Notes")
      expect(app.frontmatter(resource)).to start_with("---\n")
    end
  end

  describe "#export" do
    it "writes the note into the configured vault" do
      vault = Dir.mktmpdir("vault")
      resource = Obsidian::Import::Resource.new(type: "book", title: "Dune", source: "Open Library", source_id: "OL1")
      path = app.export(resource, vault_path: vault)
      expect(File.read(path)).to include("title: Dune")
    ensure
      FileUtils.rm_rf(vault)
    end
  end
end
