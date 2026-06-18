# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::TMDb do
  subject(:adapter) { described_class.new }

  let(:movie_json) do
    {
      "id" => 27205,
      "title" => "Inception",
      "overview" => "A thief who steals corporate secrets through dream-sharing.",
      "release_date" => "2010-07-16",
      "poster_path" => "/abc.jpg",
      "vote_average" => 8.4,
      "genres" => [{"id" => 28, "name" => "Action"}, {"id" => 878, "name" => "Science Fiction"}],
      "runtime" => 148,
      "status" => "Released",
      "homepage" => "https://www.warnerbros.com/movies/inception",
      "tagline" => "Your mind is the scene of the crime."
    }
  end

  let(:tv_json) do
    {
      "id" => 1396,
      "name" => "Breaking Bad",
      "overview" => "A chemistry teacher turned methamphetamine producer.",
      "first_air_date" => "2008-01-20",
      "poster_path" => "/xyz.jpg",
      "vote_average" => 8.9,
      "genres" => [{"id" => 18, "name" => "Drama"}],
      "status" => "Ended",
      "homepage" => "https://www.amc.com/shows/breaking-bad"
    }
  end

  describe "registration" do
    it "declares its types and source" do
      expect(described_class.object_types).to eq(["movie", "tv_show"])
      expect(adapter.source).to eq("TMDb")
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a movie from the /movie endpoint" do
      ENV["TMDB_API_KEY"] = "testkey"
      stub_request(:get, "https://api.themoviedb.org/3/movie/27205")
        .with(query: hash_including("api_key" => "testkey"))
        .to_return(status: 200, body: JSON.generate(movie_json))

      resource = adapter.lookup(id: "27205")
      expect(resource.type).to eq("movie")
      expect(resource.subtype).to be_nil
      expect(resource.title).to eq("Inception")
      expect(resource.source_id).to eq("27205")
      expect(resource.source).to eq("TMDb")
      expect(resource.source_url).to eq("https://www.themoviedb.org/movie/27205")
      expect(resource.description).to eq("A thief who steals corporate secrets through dream-sharing.")
      expect(resource.metadata["release_date"]).to eq("2010-07-16")
      expect(resource.metadata["rating"]).to eq(8.4)
      expect(resource.metadata["poster_url"]).to eq("https://image.tmdb.org/t/p/w500/abc.jpg")
      expect(resource.metadata["genres"]).to eq(["Action", "Science Fiction"])
      expect(resource.metadata["status"]).to eq("Released")
      expect(resource.metadata["homepage_url"]).to eq("https://www.warnerbros.com/movies/inception")
      expect(resource.tags).to eq(["movie"])
    end

    it "raises NotFoundError for a missing record" do
      ENV["TMDB_API_KEY"] = "testkey"
      stub_request(:get, "https://api.themoviedb.org/3/movie/0")
        .with(query: hash_including("api_key" => "testkey"))
        .to_return(status: 404, body: "")
      expect { adapter.lookup(id: "0") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#search" do
    subject(:tv_adapter) { described_class.new(type: "tv_show") }

    it "queries the /tv endpoint and normalizes each result" do
      ENV["TMDB_API_KEY"] = "testkey"
      stub_request(:get, "https://api.themoviedb.org/3/search/tv")
        .with(query: hash_including("api_key" => "testkey", "query" => "breaking bad"))
        .to_return(status: 200, body: JSON.generate("results" => [tv_json]))

      results = tv_adapter.search(query: "breaking bad")
      expect(results.size).to eq(1)
      resource = results.first
      expect(resource).to be_a(Obsidian::Import::Resource)
      expect(resource.type).to eq("tv_show")
      expect(resource.title).to eq("Breaking Bad")
      expect(resource.source_url).to eq("https://www.themoviedb.org/tv/1396")
      expect(resource.metadata["release_date"]).to eq("2008-01-20")
      expect(resource.metadata["genres"]).to eq(["Drama"])
      expect(resource.tags).to eq(["tv_show"])
    end

    it "tolerates an empty result set" do
      ENV["TMDB_API_KEY"] = "testkey"
      stub_request(:get, "https://api.themoviedb.org/3/search/tv")
        .with(query: hash_including("api_key" => "testkey", "query" => "zzz"))
        .to_return(status: 200, body: JSON.generate("results" => []))
      expect(tv_adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "credentials" do
    it "raises MissingCredentialError when no api key is configured" do
      ENV.delete("TMDB_API_KEY")
      expect { adapter.search(query: "anything") }
        .to raise_error(Obsidian::Import::MissingCredentialError)
    end
  end
end
