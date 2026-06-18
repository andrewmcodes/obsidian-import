# frozen_string_literal: true

require "stringio"

RSpec.describe Obsidian::Import::CLI do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  def run(*argv)
    described_class.new(out: out, err: err, application: app).run(argv)
  end

  let(:app) { Obsidian::Import::Application.new(config: Obsidian::Import::Configuration.load) }

  let(:gem_json) do
    {"name" => "rails", "info" => "Web framework.", "version" => "8.0.0",
     "project_uri" => "https://rubygems.org/gems/rails"}
  end

  describe "types" do
    it "lists the registered types" do
      expect(run("types")).to eq(0)
      expect(out.string).to include("gem", "Ruby Gem", "requires API key")
    end
  end

  describe "version / help" do
    it "prints the version" do
      expect(run("--version")).to eq(0)
      expect(out.string).to include(Obsidian::Import::VERSION)
    end

    it "prints help with --help" do
      expect(run("--help")).to eq(0)
      expect(out.string).to include("Usage:")
    end
  end

  describe "interactive TUI" do
    it "launches the TUI with no arguments" do
      allow(Obsidian::Import::TUI).to receive(:start).and_return(0)
      expect(run).to eq(0)
      expect(Obsidian::Import::TUI).to have_received(:start)
    end

    it "launches the TUI via the tui subcommand" do
      allow(Obsidian::Import::TUI).to receive(:start).and_return(0)
      expect(run("tui")).to eq(0)
      expect(Obsidian::Import::TUI).to have_received(:start)
    end
  end

  describe "search" do
    it "lists numbered results" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "rails"}).to_return(status: 200, body: JSON.generate([gem_json]))
      expect(run("search", "gem", "rails")).to eq(0)
      expect(out.string).to include(" 1. rails", "Web framework.")
    end

    it "reports an empty result set" do
      stub_request(:get, "https://rubygems.org/api/v1/search.json")
        .with(query: {"query" => "zzz"}).to_return(status: 200, body: "[]")
      expect(run("search", "gem", "zzz")).to eq(0)
      expect(out.string).to include("No results")
    end

    it "errors without arguments" do
      expect(run("search")).to eq(1)
      expect(err.string).to include("search requires")
    end
  end

  describe "show" do
    before do
      stub_request(:get, "https://rubygems.org/api/v1/gems/rails.json")
        .to_return(status: 200, body: JSON.generate(gem_json))
    end

    it "prints the full note by default" do
      expect(run("show", "gem", "rails")).to eq(0)
      expect(out.string).to include("title: rails", "## Notes")
    end

    it "prints only frontmatter with --frontmatter" do
      expect(run("show", "gem", "rails", "--frontmatter")).to eq(0)
      expect(out.string).to include("title: rails")
      expect(out.string).not_to include("## Notes")
    end
  end

  describe "export" do
    it "writes a note and prints its path" do
      vault = Dir.mktmpdir("vault")
      stub_request(:get, "https://rubygems.org/api/v1/gems/rails.json")
        .to_return(status: 200, body: JSON.generate(gem_json))
      expect(run("export", "gem", "rails", "--vault", vault)).to eq(0)
      expect(out.string).to include("Created note:")
    ensure
      FileUtils.rm_rf(vault)
    end
  end

  describe "config init" do
    it "writes a config file with user-only permissions" do
      expect(run("config", "init")).to eq(0)
      path = Obsidian::Import::Configuration.config_file_path
      expect(File.exist?(path)).to be(true)
      expect(format("%o", File.stat(path).mode & 0o777)).to eq("600")
    end

    it "refuses to overwrite without --force" do
      run("config", "init")
      expect(run("config", "init")).to eq(1)
      expect(err.string).to include("already exists")
    end
  end

  describe "error handling" do
    it "renders adapter errors as friendly messages" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/nope.json").to_return(status: 404, body: "")
      expect(run("show", "gem", "nope")).to eq(1)
      expect(err.string).to start_with("Error:")
    end

    it "rejects unknown commands" do
      expect(run("frobnicate")).to eq(1)
      expect(err.string).to include("Unknown command")
    end
  end
end
