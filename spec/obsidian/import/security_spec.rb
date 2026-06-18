# frozen_string_literal: true

# End-to-end guarantees that credentials never leak into the cache or errors.
RSpec.describe "credential safety" do
  def cache_files
    Dir.glob(File.join(Obsidian::Import::Cache.default_dir, "*.json"))
  end

  def cache_contents
    cache_files.map { |f| File.read(f) }.join("\n")
  end

  describe "a GitHub lookup authenticated with a header token" do
    it "never writes the token or Authorization header into the cache" do
      ENV["GITHUB_TOKEN"] = "ghp_supersecrettoken"
      body = JSON.generate("full_name" => "rails/rails", "html_url" => "https://github.com/rails/rails")
      stub_request(:get, "https://api.github.com/repos/rails/rails")
        .with(headers: {"Authorization" => "Bearer ghp_supersecrettoken"})
        .to_return(status: 200, body: body)

      Obsidian::Import::Adapters::GitHub.new(config: Obsidian::Import::Configuration.load)
        .lookup(id: "rails/rails")

      expect(cache_files).not_to be_empty
      expect(cache_contents).not_to include("ghp_supersecrettoken")
      expect(cache_contents).not_to include("Authorization")
    ensure
      ENV.delete("GITHUB_TOKEN")
    end
  end

  describe "a TMDb request authenticated with an api_key query param" do
    it "excludes the key from the cache (filename and contents)" do
      ENV["TMDB_API_KEY"] = "tmdb_supersecret"
      stub_request(:get, "https://api.themoviedb.org/3/search/movie")
        .with(query: hash_including("api_key" => "tmdb_supersecret", "query" => "dune"))
        .to_return(status: 200, body: JSON.generate("results" => [{"id" => 1, "title" => "Dune"}]))

      Obsidian::Import::Adapters::TMDb.new(type: "movie", config: Obsidian::Import::Configuration.load)
        .search(query: "dune")

      expect(cache_files).not_to be_empty
      expect(cache_contents).not_to include("tmdb_supersecret")
    ensure
      ENV.delete("TMDB_API_KEY")
    end

    it "redacts the key from error messages" do
      ENV["TMDB_API_KEY"] = "tmdb_supersecret"
      stub_request(:get, "https://api.themoviedb.org/3/movie/999")
        .with(query: hash_including("api_key" => "tmdb_supersecret"))
        .to_return(status: 404, body: "")

      adapter = Obsidian::Import::Adapters::TMDb.new(type: "movie", config: Obsidian::Import::Configuration.load)
      expect { adapter.lookup(id: "999") }.to raise_error(Obsidian::Import::NotFoundError) { |e|
        expect(e.message).not_to include("tmdb_supersecret")
      }
    ensure
      ENV.delete("TMDB_API_KEY")
    end
  end
end
