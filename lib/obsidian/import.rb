# frozen_string_literal: true

require "zeitwerk"

require_relative "import/version"

# Top-level Obsidian namespace.
module Obsidian
  # obsidian-import: import structured metadata from canonical sources into an
  # Obsidian vault as plain, human-editable Markdown notes.
  #
  # The {Import} module is the UI-agnostic entry point. It exposes a Zeitwerk
  # loader so the rest of the library autoloads on demand, and convenience
  # accessors for the global {Configuration}.
  module Import
    # Base error class for the library. All library-raised errors descend from
    # this so callers can rescue a single type.
    class Error < StandardError; end

    # Raised when configuration is missing or invalid (e.g. no vault path).
    class ConfigurationError < Error; end

    # Raised when a requested object type has no registered adapter.
    class UnknownTypeError < Error; end

    # Base class for errors originating from a source adapter / its API.
    class AdapterError < Error; end

    # Raised when a required API credential is absent.
    class MissingCredentialError < AdapterError; end

    # Raised when a lookup or search returns no matching record.
    class NotFoundError < AdapterError; end

    # Raised when an API rejects the request due to authentication.
    class AuthenticationError < AdapterError; end

    # Raised when an API signals a rate limit.
    class RateLimitError < AdapterError; end

    # Raised when the network request itself fails (timeout, DNS, etc.).
    class NetworkError < AdapterError; end

    # Raised when an API responds with an unexpected or malformed payload.
    class ResponseError < AdapterError; end

    # Raised when writing a note into the vault fails.
    class ExportError < Error; end

    class << self
      # @return [Zeitwerk::Loader] the loader managing autoloading for the gem.
      attr_reader :loader

      # Configure the global library settings.
      #
      # @yield [Configuration::Settings] the mutable settings object
      # @return [void]
      def configure(&)
        configuration.configure(&)
      end

      # @return [Configuration] the global configuration, loaded from disk and
      #   the environment on first access.
      def configuration
        @configuration ||= Configuration.load
      end

      # Reset the memoized configuration. Primarily a test seam.
      #
      # @return [void]
      def reset_configuration!
        @configuration = nil
      end
    end
  end
end

lib_root = File.expand_path("..", __dir__)
loader = Zeitwerk::Loader.new
loader.tag = "obsidian-import"
loader.push_dir(lib_root)
loader.ignore(File.join(lib_root, "obsidian", "import", "version.rb"))
loader.inflector.inflect(
  "cli" => "CLI",
  "tui" => "TUI",
  "http" => "HTTP",
  "npm" => "Npm",
  "github" => "GitHub",
  "tmdb" => "TMDb",
  "url" => "URL"
)
loader.setup
Obsidian::Import.instance_variable_set(:@loader, loader)
