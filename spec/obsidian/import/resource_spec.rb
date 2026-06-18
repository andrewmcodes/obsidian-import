# frozen_string_literal: true

RSpec.describe Obsidian::Import::Resource do
  subject(:resource) do
    described_class.new(
      type: :gem,
      title: "ViewComponent",
      source: "RubyGems",
      source_id: :view_component,
      subtype: :gem,
      description: "Reusable view components.",
      source_url: "https://rubygems.org/gems/view_component",
      metadata: {"version" => "4.0.0", "blank" => nil, "empty" => "", "list" => []},
      tags: [:rails, "ruby"]
    )
  end

  it "stringifies core scalar fields" do
    expect(resource.type).to eq("gem")
    expect(resource.subtype).to eq("gem")
    expect(resource.source_id).to eq("view_component")
  end

  it "stringifies tags" do
    expect(resource.tags).to eq(%w[rails ruby])
  end

  it "drops nil and empty metadata values" do
    expect(resource.metadata).to eq("version" => "4.0.0")
  end

  it "exposes core fields in canonical order" do
    expect(resource.core_fields.keys).to eq(%i[type subtype title description source source_id source_url])
  end

  it "is frozen and immutable" do
    expect(resource).to be_frozen
  end

  describe "equality" do
    it "is equal to a resource with identical fields" do
      other = described_class.new(type: "gem", title: "X", source: "S", source_id: "1")
      same = described_class.new(type: "gem", title: "X", source: "S", source_id: "1")
      expect(other).to eq(same)
      expect(other.hash).to eq(same.hash)
      expect([other]).to include(same)
    end

    it "is not equal to a non-resource" do
      expect(resource).not_to eq("nope")
    end
  end

  it "allows minimal construction" do
    minimal = described_class.new(type: "book", title: "T", source: "Open Library", source_id: "OL1")
    expect(minimal.subtype).to be_nil
    expect(minimal.metadata).to eq({})
    expect(minimal.tags).to eq([])
  end
end
