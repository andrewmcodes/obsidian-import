# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::GitHub do
  subject(:adapter) { described_class.new }

  let(:repo_json) do
    {
      "full_name" => "ViewComponent/view_component",
      "name" => "view_component",
      "description" => "A framework for building reusable, testable & encapsulated view components in Ruby on Rails.",
      "html_url" => "https://github.com/ViewComponent/view_component",
      "stargazers_count" => 3456,
      "forks_count" => 789,
      "language" => "Ruby",
      "license" => {"spdx_id" => "MIT"},
      "topics" => ["rails", "view-components"],
      "homepage" => "https://viewcomponent.org",
      "owner" => {"login" => "ViewComponent"}
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["github_repo"])
      expect(adapter.source).to eq("GitHub")
    end
  end

  describe "request headers" do
    let(:base_headers) do
      {
        "Accept" => "application/vnd.github+json",
        "User-Agent" => "obsidian-import",
        "X-GitHub-Api-Version" => "2022-11-28"
      }
    end

    it "includes an Authorization header when a token is configured" do
      ENV["GITHUB_TOKEN"] = "ghp_secret"
      Obsidian::Import.reset_configuration!

      stub_request(:get, "https://api.github.com/repos/ViewComponent/view_component")
        .with(headers: base_headers.merge("Authorization" => "Bearer ghp_secret"))
        .to_return(status: 200, body: JSON.generate(repo_json))

      adapter.lookup(id: "ViewComponent/view_component")
    end

    it "omits the Authorization header when no token is configured" do
      stub = stub_request(:get, "https://api.github.com/repos/ViewComponent/view_component")
        .with(headers: base_headers)
        .to_return(status: 200, body: JSON.generate(repo_json))

      adapter.lookup(id: "ViewComponent/view_component")

      expect(stub).to have_been_requested
      expect(
        a_request(:get, "https://api.github.com/repos/ViewComponent/view_component")
          .with(headers: {"Authorization" => "Bearer ghp_secret"})
      ).not_to have_been_made
    end
  end

  describe "#search" do
    it "normalizes each result" do
      stub_request(:get, "https://api.github.com/search/repositories")
        .with(query: {"q" => "view_component", "per_page" => "10"})
        .to_return(status: 200, body: JSON.generate("items" => [repo_json]))

      results = adapter.search(query: "view_component")
      expect(results.map(&:title)).to eq(["ViewComponent/view_component"])
      expect(results.first).to be_a(Obsidian::Import::Resource)
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://api.github.com/search/repositories")
        .with(query: {"q" => "zzz", "per_page" => "10"})
        .to_return(status: 200, body: JSON.generate("items" => []))

      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a single repository" do
      stub_request(:get, "https://api.github.com/repos/ViewComponent/view_component")
        .to_return(status: 200, body: JSON.generate(repo_json))

      resource = adapter.lookup(id: "ViewComponent/view_component")
      expect(resource.type).to eq("github_repo")
      expect(resource.subtype).to be_nil
      expect(resource.title).to eq("ViewComponent/view_component")
      expect(resource.source_id).to eq("ViewComponent/view_component")
      expect(resource.source_url).to eq("https://github.com/ViewComponent/view_component")
      expect(resource.metadata["stars"]).to eq(3456)
      expect(resource.metadata["forks"]).to eq(789)
      expect(resource.metadata["language"]).to eq("Ruby")
      expect(resource.metadata["topics"]).to eq(["rails", "view-components"])
      expect(resource.tags).to eq(["github"])
    end

    it "raises NotFoundError for a missing repository" do
      stub_request(:get, "https://api.github.com/repos/nope/nope")
        .to_return(status: 404, body: "")

      expect { adapter.lookup(id: "nope/nope") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#normalize" do
    it "maps license.spdx_id and owner.login" do
      resource = adapter.normalize(record: repo_json)
      expect(resource.metadata["license"]).to eq("MIT")
      expect(resource.metadata["owner"]).to eq("ViewComponent")
    end
  end
end
