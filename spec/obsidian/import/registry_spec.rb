# frozen_string_literal: true

RSpec.describe Obsidian::Import::Registry do
  it "registers every PRD object type" do
    expect(described_class.types).to match_array(
      %w[book gem npm_package github_repo app movie tv_show podcast]
    )
  end

  describe ".known?" do
    it "is true for registered types and false otherwise" do
      expect(described_class.known?(:gem)).to be(true)
      expect(described_class.known?("nope")).to be(false)
    end
  end

  describe ".label_for" do
    it "returns the display label" do
      expect(described_class.label_for("npm_package")).to eq("npm Package")
    end
  end

  describe ".requires_key?" do
    it "flags keyed sources" do
      expect(described_class.requires_key?("movie")).to be(true)
      expect(described_class.requires_key?("gem")).to be(false)
    end
  end

  describe ".adapter_for" do
    it "instantiates the adapter carrying the requested type" do
      adapter = described_class.adapter_for("tv_show")
      expect(adapter).to be_a(Obsidian::Import::Adapters::TMDb)
      expect(adapter.type).to eq("tv_show")
    end

    it "raises UnknownTypeError for unregistered types" do
      expect { described_class.adapter_for("widget") }
        .to raise_error(Obsidian::Import::UnknownTypeError, /widget/)
    end
  end
end
