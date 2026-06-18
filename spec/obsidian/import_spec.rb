# frozen_string_literal: true

RSpec.describe Obsidian::Import do
  it "has a version number" do
    expect(Obsidian::Import::VERSION).not_to be_nil
  end

  it "exposes a Zeitwerk loader" do
    expect(Obsidian::Import.loader).to be_a(Zeitwerk::Loader)
  end

  describe ".configuration" do
    it "memoizes a Configuration instance" do
      expect(described_class.configuration).to be_a(Obsidian::Import::Configuration)
      expect(described_class.configuration).to equal(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the underlying settings" do
      described_class.configure { |c| c.cache_ttl = 5 }
      expect(described_class.configuration.cache_ttl).to eq(5)
    end
  end

  describe ".reset_configuration!" do
    it "drops the memoized configuration" do
      first = described_class.configuration
      described_class.reset_configuration!
      expect(described_class.configuration).not_to equal(first)
    end
  end
end
