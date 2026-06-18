# frozen_string_literal: true

RSpec.describe Obsidian::Import::Cache do
  subject(:cache) { described_class.new(dir: dir, ttl: 100) }

  let(:dir) { File.join(ENV["XDG_CACHE_HOME"], "obsidian-import") }

  describe ".default_dir" do
    it "honors XDG_CACHE_HOME" do
      expect(described_class.default_dir).to eq(File.join(ENV["XDG_CACHE_HOME"], "obsidian-import"))
    end
  end

  describe "#fetch" do
    it "computes and stores on a miss" do
      calls = 0
      value = cache.fetch("k") {
        calls += 1
        {"a" => 1}
      }
      expect(value).to eq("a" => 1)
      expect(calls).to eq(1)
    end

    it "returns the cached value on a hit without re-running the block" do
      cache.fetch("k") { {"a" => 1} }
      calls = 0
      value = cache.fetch("k") {
        calls += 1
        {"a" => 2}
      }
      expect(value).to eq("a" => 1)
      expect(calls).to eq(0)
    end
  end

  describe "#read" do
    it "returns nil for a missing key" do
      expect(cache.read("absent")).to be_nil
    end

    it "returns nil for an expired entry" do
      cache.write("k", "v")
      expect(cache.read("k", ttl: 0)).to be_nil
    end

    it "expires entries strictly older than the TTL but keeps fresh ones" do
      allow(cache).to receive(:now).and_return(1_000)
      cache.write("k", "v")
      allow(cache).to receive(:now).and_return(1_000 + 100) # exactly ttl => not fresh
      expect(cache.read("k", ttl: 100)).to be_nil
      allow(cache).to receive(:now).and_return(1_000 + 99) # within ttl => fresh
      expect(cache.read("k", ttl: 100)).to eq("v")
    end

    it "returns nil (not an error) when the file vanishes after a check" do
      cache.write("k", "v")
      cache.clear
      expect { cache.read("k") }.not_to raise_error
      expect(cache.read("k")).to be_nil
    end

    it "returns nil for corrupt JSON" do
      path = Dir.glob(File.join(dir, "*.json")).first || begin
        cache.write("k", "v")
        Dir.glob(File.join(dir, "*.json")).first
      end
      File.write(path, "{not json")
      expect(cache.read("k")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all entries" do
      cache.write("k", "v")
      cache.clear
      expect(cache.read("k")).to be_nil
    end
  end

  it "hashes keys so filenames never expose the raw key" do
    cache.write("rubygems:gem:secret-ish", "v")
    names = Dir.glob(File.join(dir, "*.json")).map { |p| File.basename(p) }
    expect(names.first).to match(/\A[0-9a-f]{64}\.json\z/)
  end
end
