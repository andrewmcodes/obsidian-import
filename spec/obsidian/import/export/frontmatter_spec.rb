# frozen_string_literal: true

RSpec.describe Obsidian::Import::Export::Frontmatter do
  let(:resource) do
    Obsidian::Import::Resource.new(
      type: "gem", subtype: "gem", title: "ViewComponent",
      description: "Reusable view components for Rails.",
      source: "RubyGems", source_id: "view_component",
      source_url: "https://rubygems.org/gems/view_component",
      metadata: {"version" => "4.0.0", "authors" => ["a", "b"]},
      tags: ["ruby"]
    )
  end

  describe ".render" do
    subject(:yaml) { described_class.render(resource) }

    it "wraps in --- delimiters" do
      expect(yaml).to start_with("---\n")
      expect(yaml).to end_with("---\n")
    end

    it "orders core fields first" do
      keys = yaml.lines.grep(/\A\w+:/).map { |l| l[/\A\w+/] }
      expect(keys.first(7)).to eq(%w[type subtype title description source source_id source_url])
    end

    it "flattens metadata after core fields and renders tags last" do
      expect(yaml).to include("version: 4.0.0")
      expect(yaml.index("tags:")).to be > yaml.index("version:")
    end

    it "round-trips as valid YAML" do
      parsed = YAML.safe_load(yaml.delete_prefix("---\n").delete_suffix("---\n"))
      expect(parsed["title"]).to eq("ViewComponent")
      expect(parsed["authors"]).to eq(%w[a b])
    end

    it "renders an empty tags list as []" do
      bare = Obsidian::Import::Resource.new(type: "book", title: "T", source: "S", source_id: "1")
      expect(described_class.render(bare)).to include("tags: []")
    end

    it "does not hard-wrap long descriptions" do
      long = "word " * 60
      res = Obsidian::Import::Resource.new(type: "book", title: "T", source: "S", source_id: "1", description: long)
      description_line = described_class.render(res).lines.find { |l| l.start_with?("description:") }
      expect(description_line).to include(long.strip)
    end

    it "round-trips unicode titles through YAML safely" do
      res = Obsidian::Import::Resource.new(type: "book", title: "日本語 — 本 “quotes”", source: "S", source_id: "1")
      parsed = YAML.safe_load(described_class.render(res).delete_prefix("---\n").delete_suffix("---\n"))
      expect(parsed["title"]).to eq("日本語 — 本 “quotes”")
    end

    it "keeps a description with embedded ---/colons inside the frontmatter block" do
      nasty = "line one: value\n---\nnot a delimiter: x"
      res = Obsidian::Import::Resource.new(type: "book", title: "T", source: "S", source_id: "1", description: nasty)
      yaml = described_class.render(res)
      inner = yaml.delete_prefix("---\n").delete_suffix("---\n")
      expect(YAML.safe_load(inner)["description"]).to eq(nasty)
    end
  end

  describe ".scalarize" do
    it "collapses nested hashes to their string form rather than nesting them" do
      expect(described_class.scalarize({"a" => 1})).to eq({"a" => 1}.to_s)
    end

    it "collapses hashes nested inside arrays" do
      expect(described_class.scalarize([{"a" => 1}, "b"])).to eq([{"a" => 1}.to_s, "b"])
    end
  end
end
