# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "stringio"

RSpec.describe Obsidian::Import::TUI::App do
  subject(:model) { described_class.new(application) }

  let(:application) { Obsidian::Import::Application.new(config: Obsidian::Import::Configuration.load) }

  let(:gem_json) do
    {"name" => "rails", "info" => "Web framework.", "version" => "8.0.0",
     "project_uri" => "https://rubygems.org/gems/rails"}
  end

  def key(type)
    const = Bubbletea::KeyMessage.const_get("KEY_#{type.to_s.upcase}")
    Bubbletea::KeyMessage.new(key_type: const)
  end

  def char(character)
    Bubbletea::KeyMessage.new(key_type: Bubbletea::KeyMessage::KEY_RUNES, runes: [character.ord])
  end

  def press(*messages)
    messages.each { |m| model.update(m) }
    model
  end

  def type_query(text)
    text.each_char { |c| model.update(char(c)) }
  end

  it "renders the home screen with the type list" do
    expect(model.view).to include("obsidian-import", "Select an object type", "Ruby Gem")
  end

  it "ignores non-key messages" do
    expect { model.update(Object.new) }.not_to raise_error
  end

  it "quits on ctrl+c" do
    _, command = model.update(Bubbletea::KeyMessage.new(key_type: Bubbletea::KeyMessage::KEY_CTRL_C))
    expect(command).not_to be_nil
  end

  describe "the search flow" do
    before do
      # Navigate Home: book(0) -> gem(1), then enter the Search screen.
      press(key(:down), key(:enter))
    end

    it "moves to the search screen for the chosen type" do
      expect(model.view).to include("Search Ruby Gem")
    end

    it "edits the query as characters are typed and removed" do
      type_query("railz")
      model.update(key(:backspace))
      type_query("s")
      expect(model.view).to include("rail")
    end

    it "runs a search and shows results, then previews a selection" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "rails"}).to_return(status: 200, body: JSON.generate([gem_json]))

      type_query("rails")
      model.update(key(:enter))
      expect(model.view).to include("Results for", "rails")

      model.update(key(:enter))
      preview = model.view
      expect(preview).to include("type:", "gem", "source:", "RubyGems")
    end

    it "reports an empty result set without leaving the search screen" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "zzz"}).to_return(status: 200, body: "[]")
      type_query("zzz")
      model.update(key(:enter))
      expect(model.view).to include("No results", "Search Ruby Gem")
    end

    it "surfaces adapter errors as friendly messages" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "boom"}).to_return(status: 500, body: "")
      type_query("boom")
      model.update(key(:enter))
      expect(model.view).to include("Error:")
    end

    it "returns to home from search on esc" do
      model.update(key(:esc))
      expect(model.view).to include("Select an object type")
    end
  end

  describe "preview actions" do
    before do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "rails"}).to_return(status: 200, body: JSON.generate([gem_json]))
      press(key(:down), key(:enter))
      type_query("rails")
      press(key(:enter), key(:enter)) # search -> results -> preview
    end

    it "creates a note into the configured vault" do
      vault = Dir.mktmpdir("vault")
      ENV["OBSIDIAN_VAULT"] = vault
      Obsidian::Import.reset_configuration!
      app = Obsidian::Import::Application.new(config: Obsidian::Import::Configuration.load)
      m = described_class.new(app)
      press_into(m)
      m.update(char("c"))
      expect(m.view).to include("Created note:")
    ensure
      ENV.delete("OBSIDIAN_VAULT")
      FileUtils.rm_rf(vault)
    end

    it "reports when the clipboard tool is unavailable" do
      allow(model).to receive(:system).and_return(false)
      model.update(char("y"))
      expect(model.view).to include("Clipboard unavailable")
    end

    it "returns to results on esc" do
      model.update(key(:esc))
      expect(model.view).to include("Results for")
    end

    def press_into(m)
      m.update(key(:down))
      m.update(key(:enter))
      "rails".each_char { |c| m.update(char(c)) }
      m.update(key(:enter))
      m.update(key(:enter))
    end
  end
end

RSpec.describe Obsidian::Import::TUI do
  it "fails gracefully when the Charm gems are unavailable" do
    out = StringIO.new
    allow(described_class).to receive(:require).and_raise(LoadError.new("no bubbletea"))
    status = described_class.start(out: out)
    expect(status).to eq(1)
    expect(out.string).to include("interactive TUI requires")
  end
end
