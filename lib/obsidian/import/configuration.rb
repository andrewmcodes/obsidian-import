# frozen_string_literal: true

require "dry/configurable"
require "yaml"
require "fileutils"

module Obsidian
  module Import
    # Global, UI-agnostic configuration for the library.
    #
    # Settings are sourced, in order of precedence, from:
    #
    # 1. Explicit {#configure} blocks (highest precedence at runtime)
    # 2. Environment variables (for API credentials and the vault path)
    # 3. The YAML config file at {.config_file_path}
    # 4. Built-in defaults
    #
    # Credentials are never written to logs, caches, or generated notes.
    #
    # @example Read the configured vault path
    #   Obsidian::Import.configuration.vault_path
    class Configuration
      include Dry::Configurable

      # Default vault-relative folder for each object type.
      DEFAULT_FOLDERS = {
        "book" => "Books",
        "gem" => "Gems",
        "npm_package" => "npm Packages",
        "github_repo" => "GitHub Repositories",
        "app" => "Apps",
        "vscode_extension" => "VS Code Extensions",
        "movie" => "Movies",
        "tv_show" => "TV Shows",
        "podcast" => "Podcasts"
      }.freeze

      # Maps logical API-key names to their environment-variable overrides.
      ENV_KEYS = {
        "tmdb" => "TMDB_API_KEY",
        "github" => "GITHUB_TOKEN",
        "listen_notes" => "LISTEN_NOTES_API_KEY"
      }.freeze

      setting :vault_path, default: nil
      setting :folders, default: DEFAULT_FOLDERS
      setting :api_keys, default: {}
      setting :cache_ttl, default: 86_400

      class << self
        # Build a configuration from the environment and the on-disk YAML file.
        #
        # @param path [String] the YAML config file to read
        # @return [Configuration]
        def load(path: config_file_path)
          new.tap { |config| config.send(:apply_sources, path) }
        end

        # @return [String] the directory holding the config file, honoring
        #   +XDG_CONFIG_HOME+ and falling back to +~/.config+.
        def config_dir
          base = ENV["XDG_CONFIG_HOME"]
          base = File.expand_path("~/.config") if base.nil? || base.empty?
          File.join(base, "obsidian-import")
        end

        # @return [String] absolute path to the YAML config file.
        def config_file_path
          File.join(config_dir, "config.yml")
        end

        # Write a starter config file with user-only permissions.
        #
        # @param path [String] destination path
        # @param force [Boolean] overwrite an existing file
        # @return [String] the path written
        # @raise [ConfigurationError] if the file exists and +force+ is false
        def init!(path: config_file_path, force: false)
          if File.exist?(path) && !force
            raise ConfigurationError, "Config already exists at #{path}. Pass --force to overwrite."
          end

          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, template_yaml)
          begin
            File.chmod(0o600, path)
          rescue SystemCallError, NotImplementedError
            # Permissions are best-effort where the platform supports them.
          end
          path
        end

        # @return [String] a commented YAML template for +config init+.
        def template_yaml
          <<~YAML
            # obsidian-import configuration
            # Path to your Obsidian vault. Required to create notes.
            vault_path: ~/Documents/Obsidian

            # Vault-relative folder for each object type.
            folders:
            #{DEFAULT_FOLDERS.map { |k, v| "  #{k}: #{v}" }.join("\n")}

            # API credentials. Prefer environment variables for secrets:
            #   TMDB_API_KEY, GITHUB_TOKEN, LISTEN_NOTES_API_KEY
            api_keys:
              tmdb: ""
              github: ""
              listen_notes: ""
          YAML
        end
      end

      # @return [String, nil] absolute vault path, or nil if unset.
      def vault_path
        raw = ENV.fetch("OBSIDIAN_VAULT", nil)
        raw = config.vault_path if raw.nil? || raw.empty?
        raw = raw.to_s.strip
        return nil if raw.empty?
        File.expand_path(raw)
      end

      # @return [Hash{String=>String}] type => folder mappings (defaults merged).
      def folders
        DEFAULT_FOLDERS.merge(config.folders || {})
      end

      # Resolve the vault-relative folder for an object type.
      #
      # @param type [String, Symbol]
      # @return [String]
      def folder_for(type)
        folders.fetch(type.to_s, type.to_s)
      end

      # Resolve an API credential, preferring the environment over the file.
      #
      # @param name [String, Symbol] logical key name, e.g. "tmdb"
      # @return [String, nil] the credential, or nil if unset/blank
      def api_key(name)
        key = name.to_s
        env_value = ENV.fetch(ENV_KEYS.fetch(key, ""), nil)
        value = env_value
        value = (config.api_keys || {})[key] if value.nil? || value.empty?
        value = value.to_s.strip
        return nil if value.empty?
        value
      end

      # @return [Integer] cache time-to-live in seconds.
      def cache_ttl
        config.cache_ttl
      end

      # Mutate settings directly.
      #
      # @yield [Dry::Configurable::Config]
      # @return [void]
      def configure
        yield config
      end

      private

      def apply_sources(path)
        data = read_yaml(path)
        config.vault_path = data["vault_path"] if data.key?("vault_path")
        config.folders = DEFAULT_FOLDERS.merge(stringify(data["folders"])) if data["folders"]
        config.api_keys = stringify(data["api_keys"]) if data["api_keys"]
      end

      def read_yaml(path)
        return {} unless File.exist?(path)
        parsed = YAML.safe_load_file(path) || {}
        parsed.is_a?(Hash) ? parsed : {}
      rescue Psych::SyntaxError => e
        raise ConfigurationError, "Invalid YAML in #{path}: #{e.message}"
      end

      def stringify(hash)
        (hash || {}).transform_keys(&:to_s)
      end
    end
  end
end
