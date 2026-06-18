# frozen_string_literal: true

module Obsidian
  module Import
    # High-level, UI-agnostic facade over the metadata engine.
    #
    # Both the CLI and the TUI drive the library through this single object, so
    # behavior stays consistent across interfaces. It resolves the right
    # adapter for an object type, runs searches and lookups, renders notes, and
    # writes them into the vault.
    #
    # @example Search and export a gem
    #   app = Obsidian::Import::Application.new
    #   resource = app.search("gem", "view_component").first
    #   app.export(resource)
    class Application
      # @return [Configuration]
      attr_reader :config

      # @param config [Configuration]
      def initialize(config: Obsidian::Import.configuration)
        @config = config
      end

      # @return [Array<Hash>] one entry per registered type with display data.
      def types
        Registry.types.map do |type|
          {type: type, label: Registry.label_for(type), requires_key: Registry.requires_key?(type)}
        end
      end

      # Search a source for records matching +query+.
      #
      # @param type [String, Symbol] object type
      # @param query [String]
      # @return [Array<Resource>]
      # @raise [UnknownTypeError] for an unregistered type
      # @raise [AdapterError] on API/transport failures
      def search(type, query)
        adapter_for(type).search(query: query)
      end

      # Look up a single record by its source identifier.
      #
      # @param type [String, Symbol]
      # @param id [String]
      # @return [Resource]
      def lookup(type, id)
        adapter_for(type).lookup(id: id)
      end

      # @param resource [Resource]
      # @return [Export::Note]
      def note(resource)
        Export::Note.new(resource)
      end

      # @param resource [Resource]
      # @return [String] the full Markdown note (frontmatter + body).
      def markdown(resource)
        note(resource).to_markdown
      end

      # @param resource [Resource]
      # @return [String] just the YAML frontmatter block.
      def frontmatter(resource)
        Export::Frontmatter.render(resource)
      end

      # Write a note for +resource+ into the vault.
      #
      # @param resource [Resource]
      # @param vault_path [String, nil]
      # @param folder [String, nil]
      # @return [String] absolute path of the written note
      def export(resource, vault_path: config.vault_path, folder: nil)
        exporter.export(resource, vault_path: vault_path, folder: folder)
      end

      # @return [Adapters::Base]
      def adapter_for(type)
        Registry.adapter_for(type, config: config)
      end

      private

      def exporter
        @exporter ||= Export::Exporter.new(config: config)
      end
    end
  end
end
