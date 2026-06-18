# frozen_string_literal: true

RSpec.describe Obsidian::Import::Configuration do
  def write_config(yaml)
    path = described_class.config_file_path
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, yaml)
    path
  end

  describe ".config_dir / .config_file_path" do
    it "honors XDG_CONFIG_HOME" do
      expect(described_class.config_dir).to start_with(ENV["XDG_CONFIG_HOME"])
      expect(described_class.config_file_path).to end_with("obsidian-import/config.yml")
    end
  end

  describe "#vault_path" do
    it "is nil when unset" do
      expect(described_class.load.vault_path).to be_nil
    end

    it "treats a whitespace-only value as unset" do
      write_config("vault_path: \"   \"\n")
      expect(described_class.load.vault_path).to be_nil
    end

    it "expands ~ from the config file" do
      write_config("vault_path: ~/Vault\n")
      expect(described_class.load.vault_path).to eq(File.expand_path("~/Vault"))
    end

    it "prefers the OBSIDIAN_VAULT environment variable" do
      write_config("vault_path: ~/FromFile\n")
      ENV["OBSIDIAN_VAULT"] = "/tmp/from-env"
      expect(described_class.load.vault_path).to eq("/tmp/from-env")
    ensure
      ENV.delete("OBSIDIAN_VAULT")
    end
  end

  describe "#folders / #folder_for" do
    it "returns defaults when unset" do
      expect(described_class.load.folder_for("gem")).to eq("Gems")
    end

    it "merges file overrides over defaults" do
      write_config("folders:\n  gem: Ruby Gems\n")
      config = described_class.load
      expect(config.folder_for("gem")).to eq("Ruby Gems")
      expect(config.folder_for("book")).to eq("Books")
    end

    it "falls back to the type name for unknown types" do
      expect(described_class.load.folder_for("widget")).to eq("widget")
    end
  end

  describe "#api_key" do
    it "reads from the config file" do
      write_config("api_keys:\n  tmdb: filekey\n")
      expect(described_class.load.api_key(:tmdb)).to eq("filekey")
    end

    it "prefers the environment variable" do
      write_config("api_keys:\n  tmdb: filekey\n")
      ENV["TMDB_API_KEY"] = "envkey"
      expect(described_class.load.api_key("tmdb")).to eq("envkey")
    ensure
      ENV.delete("TMDB_API_KEY")
    end

    it "returns nil for blank values" do
      write_config("api_keys:\n  tmdb: \"\"\n")
      expect(described_class.load.api_key("tmdb")).to be_nil
    end

    it "strips surrounding whitespace and treats whitespace-only as nil" do
      write_config("api_keys:\n  tmdb: \"  abc  \"\n  github: \"   \"\n")
      config = described_class.load
      expect(config.api_key("tmdb")).to eq("abc")
      expect(config.api_key("github")).to be_nil
    end
  end

  describe "invalid YAML" do
    it "raises a ConfigurationError" do
      write_config("vault_path: [unterminated\n")
      expect { described_class.load }.to raise_error(Obsidian::Import::ConfigurationError, /Invalid YAML/)
    end
  end

  describe "#configure" do
    it "mutates settings" do
      config = described_class.load
      config.configure { |c| c.cache_ttl = 1 }
      expect(config.cache_ttl).to eq(1)
    end
  end

  describe ".template_yaml" do
    it "is parseable YAML mentioning every type" do
      data = YAML.safe_load(described_class.template_yaml)
      expect(data["folders"].keys).to match_array(described_class::DEFAULT_FOLDERS.keys)
    end
  end
end
