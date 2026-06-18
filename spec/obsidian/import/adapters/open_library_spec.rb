# frozen_string_literal: true

RSpec.describe Obsidian::Import::Adapters::OpenLibrary do
  subject(:adapter) { described_class.new }

  let(:search_doc) do
    {
      "title" => "The Ruby Programming Language",
      "author_name" => ["David Flanagan", "Yukihiro Matsumoto"],
      "first_publish_year" => 2008,
      "key" => "/works/OL123W",
      "cover_i" => 456,
      "isbn" => ["9780596516178", "0596516177"],
      "subject" => ["Ruby (Computer program language)"],
      "edition_count" => 3,
      "language" => ["eng"]
    }
  end

  describe "registration" do
    it "declares its type and source" do
      expect(described_class.object_types).to eq(["book"])
      expect(adapter.source).to eq("Open Library")
    end
  end

  describe "#search" do
    it "normalizes each result" do
      stub_request(:get, "https://openlibrary.org/search.json")
        .with(query: {"q" => "ruby", "limit" => "10"})
        .to_return(status: 200, body: JSON.generate({"docs" => [search_doc]}))

      results = adapter.search(query: "ruby")
      expect(results.map(&:title)).to eq(["The Ruby Programming Language"])
      expect(results.first).to be_a(Obsidian::Import::Resource)
      expect(results.first.source_id).to eq("OL123W")
      expect(results.first.metadata["authors"]).to eq(["David Flanagan", "Yukihiro Matsumoto"])
      expect(results.first.metadata["first_published"]).to eq(2008)
      expect(results.first.metadata["cover_url"]).to eq("https://covers.openlibrary.org/b/id/456-L.jpg")
      expect(results.first.metadata["isbn"]).to eq("9780596516178")
      expect(results.first.metadata["subjects"]).to eq(["Ruby (Computer program language)"])
      expect(results.first.tags).to eq(["book"])
    end

    it "tolerates an empty result set" do
      stub_request(:get, "https://openlibrary.org/search.json")
        .with(query: {"q" => "zzz", "limit" => "10"})
        .to_return(status: 200, body: JSON.generate({"docs" => []}))

      expect(adapter.search(query: "zzz")).to eq([])
    end
  end

  describe "#lookup" do
    it "fetches and normalizes a single work" do
      stub_request(:get, "https://openlibrary.org/works/OL123W.json")
        .to_return(status: 200, body: JSON.generate({
          "title" => "The Ruby Programming Language",
          "key" => "/works/OL123W",
          "description" => "A definitive guide to Ruby.",
          "subjects" => ["Ruby (Computer program language)"],
          "covers" => [456]
        }))

      resource = adapter.lookup(id: "OL123W")
      expect(resource.type).to eq("book")
      expect(resource.subtype).to be_nil
      expect(resource.source_id).to eq("OL123W")
      expect(resource.source_url).to eq("https://openlibrary.org/works/OL123W")
      expect(resource.description).to eq("A definitive guide to Ruby.")
      expect(resource.metadata["subjects"]).to eq(["Ruby (Computer program language)"])
      # The work-lookup shape carries `covers` (array), not the search `cover_i`.
      expect(resource.metadata["cover_url"]).to eq("https://covers.openlibrary.org/b/id/456-L.jpg")
      expect(resource.tags).to eq(["book"])
    end

    it "raises NotFoundError for a missing work" do
      stub_request(:get, "https://openlibrary.org/works/OL999W.json")
        .to_return(status: 404, body: "")

      expect { adapter.lookup(id: "OL999W") }.to raise_error(Obsidian::Import::NotFoundError)
    end
  end

  describe "#normalize" do
    it "flattens a description carried as a Hash" do
      resource = adapter.normalize(record: {
        "title" => "Eloquent Ruby",
        "key" => "/works/OL777W",
        "description" => {"type" => "/type/text", "value" => "Idiomatic Ruby."}
      })

      expect(resource.description).to eq("Idiomatic Ruby.")
    end

    it "strips the /works/ prefix from the key" do
      resource = adapter.normalize(record: {"title" => "x", "key" => "/works/OL42W"})
      expect(resource.source_id).to eq("OL42W")
      expect(resource.source_url).to eq("https://openlibrary.org/works/OL42W")
    end

    it "drops missing optional fields" do
      resource = adapter.normalize(record: {"title" => "Bare", "key" => "/works/OL1W"})
      expect(resource.description).to be_nil
      expect(resource.metadata).not_to have_key("authors")
      expect(resource.metadata).not_to have_key("first_published")
      expect(resource.metadata).not_to have_key("cover_url")
      expect(resource.metadata).not_to have_key("isbn")
      expect(resource.metadata).not_to have_key("subjects")
    end

    it "treats Open Library's -1 cover sentinel as no cover" do
      resource = adapter.normalize(record: {"title" => "x", "key" => "/works/OL2W", "covers" => [-1]})
      expect(resource.metadata).not_to have_key("cover_url")
    end

    it "does not raise on an essentially empty record" do
      resource = adapter.normalize(record: {})
      expect(resource).to be_a(Obsidian::Import::Resource)
      expect(resource.source_url).to eq("https://openlibrary.org/works/")
    end
  end
end
