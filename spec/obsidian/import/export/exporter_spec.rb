# frozen_string_literal: true

RSpec.describe Obsidian::Import::Export::Exporter do
  subject(:exporter) { described_class.new(config: config) }

  let(:config) { Obsidian::Import::Configuration.load }
  let(:vault) { Dir.mktmpdir("vault") }

  def resource(type: "gem", title: "ViewComponent", **opts)
    Obsidian::Import::Resource.new(type: type, title: title, source: "RubyGems", source_id: "vc", **opts)
  end

  after { FileUtils.rm_rf(vault) }

  describe "#export" do
    it "raises ConfigurationError without a vault path" do
      expect { exporter.export(resource) }
        .to raise_error(Obsidian::Import::ConfigurationError, /vault path/)
    end

    it "creates the mapped folder and writes the note" do
      path = exporter.export(resource(subtype: "gem"), vault_path: vault)
      expect(path).to eq(File.join(vault, "Gems", "viewcomponent.gem.md"))
      expect(File.read(path)).to include("title: ViewComponent")
    end

    it "creates parent directories recursively" do
      exporter.export(resource(type: "book", title: "Dune"), vault_path: vault)
      expect(Dir.exist?(File.join(vault, "Books"))).to be(true)
    end

    it "resolves filename collisions with numeric suffixes" do
      first = exporter.export(resource(type: "book", title: "Dune"), vault_path: vault)
      second = exporter.export(resource(type: "book", title: "Dune"), vault_path: vault)
      expect(File.basename(first)).to eq("dune.md")
      expect(File.basename(second)).to eq("dune-2.md")
    end

    it "honors a folder override" do
      path = exporter.export(resource, vault_path: vault, folder: "Custom")
      expect(path).to start_with(File.join(vault, "Custom"))
    end

    it "wraps filesystem failures in ExportError" do
      allow(File).to receive(:write).and_raise(Errno::EACCES)
      expect { exporter.export(resource, vault_path: vault) }
        .to raise_error(Obsidian::Import::ExportError, /Failed to write/)
    end
  end
end
