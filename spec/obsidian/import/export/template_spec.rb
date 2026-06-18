# frozen_string_literal: true

RSpec.describe Obsidian::Import::Export::Template do
  def resource(type:, **opts)
    Obsidian::Import::Resource.new(type: type, title: "T", source: "S", source_id: "1", **opts)
  end

  describe ".template_name" do
    it "uses the software template for software types" do
      expect(described_class.template_name("gem")).to eq("software")
      expect(described_class.template_name("app")).to eq("software")
    end

    it "uses the default template otherwise" do
      expect(described_class.template_name("book")).to eq("default")
    end
  end

  describe ".body_for" do
    it "renders the software sections" do
      body = described_class.body_for(resource(type: "gem"))
      expect(body).to include("![[Software Views.base#Notes]]")
      expect(body).to include("## API Documentation", "## CLI Usage", "## Review")
    end

    it "renders a description blockquote for the default template" do
      body = described_class.body_for(resource(type: "book", description: "A great book."))
      expect(body).to include("> A great book.")
      expect(body).to include("## Notes")
    end

    it "omits the blockquote when there is no description" do
      body = described_class.body_for(resource(type: "book"))
      expect(body).not_to include(">")
    end
  end
end
