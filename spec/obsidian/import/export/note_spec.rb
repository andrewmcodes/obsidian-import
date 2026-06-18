# frozen_string_literal: true

RSpec.describe Obsidian::Import::Export::Note do
  def note(type:, **opts)
    described_class.new(
      Obsidian::Import::Resource.new(type: type, title: "View Component", source: "S", source_id: "1", **opts)
    )
  end

  describe "#to_markdown" do
    it "concatenates frontmatter and body" do
      md = note(type: "gem", subtype: "gem").to_markdown
      expect(md).to start_with("---\n")
      expect(md).to include("## Notes")
    end
  end

  describe "#slug" do
    it "slugifies the title" do
      expect(note(type: "book").slug).to eq("view-component")
    end
  end

  describe "#secondary_extension" do
    it "returns the subtype for software notes" do
      expect(note(type: "gem", subtype: "gem").secondary_extension).to eq("gem")
    end

    it "is nil for software notes without a subtype" do
      expect(note(type: "github_repo").secondary_extension).to be_nil
    end

    it "is nil for non-software notes" do
      expect(note(type: "book", subtype: "novel").secondary_extension).to be_nil
    end
  end
end
