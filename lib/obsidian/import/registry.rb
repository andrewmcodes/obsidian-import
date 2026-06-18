# frozen_string_literal: true

module Obsidian
  module Import
    # Central catalog mapping object types to their adapters and display
    # metadata. Adding support for a new type means adding one entry here.
    module Registry
      # @return [Hash{String=>Hash}] type => {adapter:, label:, requires_key:}.
      TYPES = {
        "book" => {adapter: "Adapters::OpenLibrary", label: "Book", requires_key: false},
        "gem" => {adapter: "Adapters::RubyGems", label: "Ruby Gem", requires_key: false},
        "npm_package" => {adapter: "Adapters::Npm", label: "npm Package", requires_key: false},
        "github_repo" => {adapter: "Adapters::GitHub", label: "GitHub Repository", requires_key: false},
        "app" => {adapter: "Adapters::Apple", label: "App", requires_key: false},
        "movie" => {adapter: "Adapters::TMDb", label: "Movie", requires_key: true},
        "tv_show" => {adapter: "Adapters::TMDb", label: "TV Show", requires_key: true},
        "podcast" => {adapter: "Adapters::ListenNotes", label: "Podcast", requires_key: true}
      }.freeze

      module_function

      # @return [Array<String>] all registered object types, in display order.
      def types
        TYPES.keys
      end

      # @param type [String, Symbol]
      # @return [Boolean]
      def known?(type)
        TYPES.key?(type.to_s)
      end

      # @param type [String, Symbol]
      # @return [String] the human-readable label for a type.
      def label_for(type)
        entry(type).fetch(:label)
      end

      # @param type [String, Symbol]
      # @return [Boolean] whether the type's source requires an API credential.
      def requires_key?(type)
        entry(type).fetch(:requires_key)
      end

      # Instantiate the adapter responsible for an object type.
      #
      # @param type [String, Symbol]
      # @param kwargs [Hash] forwarded to the adapter constructor
      # @return [Adapters::Base]
      # @raise [UnknownTypeError] if the type is not registered
      def adapter_for(type, **kwargs)
        klass = Obsidian::Import.const_get(entry(type).fetch(:adapter))
        klass.new(type: type.to_s, **kwargs)
      end

      # @param type [String, Symbol]
      # @return [Hash]
      # @raise [UnknownTypeError]
      def entry(type)
        TYPES.fetch(type.to_s) do
          raise UnknownTypeError, "Unknown object type '#{type}'. Known types: #{types.join(", ")}."
        end
      end
    end
  end
end
