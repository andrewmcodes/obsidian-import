# frozen_string_literal: true

module Obsidian
  module Import
    # Source adapters translate external APIs into normalized {Resource}s.
    module Adapters
      # Abstract base class implementing the adapter contract.
      #
      # Concrete adapters declare the object type(s) they support and the
      # canonical source name, then implement {#search}, {#lookup}, and
      # {#normalize}. Shared HTTP, caching, and credential handling live here so
      # a new adapter is typically a single small file.
      #
      # @abstract Subclass and implement {#search}, {#lookup}, and {#normalize}.
      #
      # @example A minimal adapter
      #   class Adapters::Example < Adapters::Base
      #     object_types "thing"
      #     source_name "Example"
      #
      #     def search(query:) = raw_search(query).map { |r| normalize(record: r) }
      #     def lookup(id:) = normalize(record: client.get("/things/#{id}"))
      #     def normalize(record:) = build(title: record["name"], source_id: record["id"])
      #   end
      class Base
        class << self
          # Declare (and read) the object types this adapter supports.
          #
          # @param types [Array<String>] one or more type identifiers
          # @return [Array<String>]
          def object_types(*types)
            @object_types = types.map(&:to_s) unless types.empty?
            @object_types || []
          end

          # Declare (and read) the canonical source name.
          #
          # @param name [String, nil]
          # @return [String, nil]
          def source_name(name = nil)
            @source_name = name if name
            @source_name
          end
        end

        # @return [Configuration]
        attr_reader :config

        # @return [Cache]
        attr_reader :cache

        # @return [String] the object type this instance is operating as.
        attr_reader :type

        # @param type [String, nil] the requested type (for multi-type adapters)
        # @param config [Configuration]
        # @param cache [Cache, nil]
        def initialize(type: nil, config: Obsidian::Import.configuration, cache: nil)
          @config = config
          @cache = cache || Cache.new(ttl: config.cache_ttl)
          @type = (type || self.class.object_types.first).to_s
        end

        # @return [String] the canonical source name.
        def source
          self.class.source_name
        end

        # Search the source for records matching +query+.
        #
        # @param query [String]
        # @return [Array<Resource>]
        # @raise [NotImplementedError] unless overridden
        def search(query:)
          raise NotImplementedError, "#{self.class} must implement #search"
        end

        # Look up a single record by its source identifier.
        #
        # @param id [String]
        # @return [Resource]
        # @raise [NotImplementedError] unless overridden
        def lookup(id:)
          raise NotImplementedError, "#{self.class} must implement #lookup"
        end

        # Normalize a raw API record into a {Resource}.
        #
        # @param record [Object]
        # @return [Resource]
        # @raise [NotImplementedError] unless overridden
        def normalize(record:)
          raise NotImplementedError, "#{self.class} must implement #normalize"
        end

        private

        # @return [HTTP::Client] lazily-built client for this adapter.
        def client
          @client ||= HTTP::Client.new(
            base_url: base_url,
            headers: request_headers,
            params: request_params,
            cache: cache,
            source: source
          )
        end

        # @return [String] the API base URL. Override in subclasses.
        def base_url
          raise NotImplementedError, "#{self.class} must implement #base_url"
        end

        # @return [Hash] default request headers.
        def request_headers
          {}
        end

        # @return [Hash] default request query params.
        def request_params
          {}
        end

        # Build a {Resource} carrying this adapter's type and source.
        #
        # @return [Resource]
        def build(title:, source_id:, subtype: nil, description: nil, source_url: nil, metadata: {}, tags: [], type: @type)
          Resource.new(
            type: type,
            subtype: subtype,
            title: title,
            description: description,
            source: source,
            source_id: source_id,
            source_url: source_url,
            metadata: metadata,
            tags: tags
          )
        end

        # Fetch a required credential or raise a friendly error.
        #
        # @param name [String, Symbol] logical key name
        # @return [String]
        # @raise [MissingCredentialError]
        def require_credential!(name)
          value = config.api_key(name)
          return value unless value.nil?

          env = Configuration::ENV_KEYS[name.to_s]
          hint = env ? "Set #{env} or " : "Set "
          raise MissingCredentialError,
            "Missing API credential for '#{name}'. #{hint}configure api_keys.#{name} in your config file."
        end
      end
    end
  end
end
