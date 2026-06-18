# frozen_string_literal: true

require "fileutils"

module Obsidian
  module Import
    module Export
      # Writes notes into an Obsidian vault.
      #
      # The target folder is derived from the configured type=>folder mapping
      # and created recursively if missing. Filenames are slugified from the
      # title with numeric suffixes resolving collisions.
      class Exporter
        # @return [Configuration]
        attr_reader :config

        # @param config [Configuration]
        def initialize(config: Obsidian::Import.configuration)
          @config = config
        end

        # Write a note for +resource+ into the vault.
        #
        # @param resource [Resource]
        # @param vault_path [String, nil] vault root (defaults to config)
        # @param folder [String, nil] override the type's default folder
        # @return [String] absolute path of the written note
        # @raise [ConfigurationError] if no vault path is configured
        # @raise [ExportError] if writing fails
        def export(resource, vault_path: config.vault_path, folder: nil)
          root = vault_path
          raise ConfigurationError, "No vault path configured. Run `obsidian-import config init` or set vault_path." if root.nil? || root.empty?

          note = Note.new(resource)
          dir = File.join(File.expand_path(root), folder || config.folder_for(resource.type))
          FileUtils.mkdir_p(dir)

          filename = Filename.unique(dir, note.slug, secondary: note.secondary_extension)
          path = File.join(dir, filename)
          File.write(path, note.to_markdown)
          path
        rescue SystemCallError => e
          raise ExportError, "Failed to write note into the vault: #{e.message}"
        end
      end
    end
  end
end
