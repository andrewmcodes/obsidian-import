# frozen_string_literal: true

module Obsidian
  module Import
    # The normalized representation every adapter produces.
    #
    # A Resource captures the standardized, source-agnostic fields used to
    # build frontmatter, plus a free-form +metadata+ hash for adapter-specific
    # values that are flattened into frontmatter at export time.
    #
    # Resources are immutable value objects: two resources with equal fields
    # are equal.
    class Resource
      # @return [String] object type, e.g. "gem", "book", "movie".
      attr_reader :type

      # @return [String, nil] finer-grained classification, e.g. "cli".
      attr_reader :subtype

      # @return [String] human-readable title.
      attr_reader :title

      # @return [String, nil] short description/summary.
      attr_reader :description

      # @return [String] canonical source name, e.g. "RubyGems".
      attr_reader :source

      # @return [String] stable identifier within the source.
      attr_reader :source_id

      # @return [String, nil] canonical URL on the source.
      attr_reader :source_url

      # @return [Hash{String=>Object}] adapter-specific metadata (flattened
      #   into frontmatter on export).
      attr_reader :metadata

      # @return [Array<String>] note tags.
      attr_reader :tags

      # @param type [String, Symbol]
      # @param title [String]
      # @param source [String]
      # @param source_id [String, Integer]
      # @param subtype [String, nil]
      # @param description [String, nil]
      # @param source_url [String, nil]
      # @param metadata [Hash]
      # @param tags [Array<String>]
      def initialize(type:, title:, source:, source_id:, subtype: nil, description: nil,
        source_url: nil, metadata: {}, tags: [])
        @type = type.to_s
        @subtype = subtype&.to_s
        @title = title.to_s
        @description = description
        @source = source.to_s
        @source_id = source_id.to_s
        @source_url = source_url
        @metadata = compact_metadata(metadata)
        @tags = Array(tags).map(&:to_s)
        freeze
      end

      # The standardized core frontmatter fields, in canonical order.
      #
      # @return [Hash{Symbol=>Object}]
      def core_fields
        {
          type: type,
          subtype: subtype,
          title: title,
          description: description,
          source: source,
          source_id: source_id,
          source_url: source_url
        }
      end

      # @return [Hash{Symbol=>Object}] all fields, including metadata and tags.
      def to_h
        core_fields.merge(metadata: metadata, tags: tags)
      end

      # @param other [Object]
      # @return [Boolean]
      def ==(other)
        other.is_a?(Resource) && to_h == other.to_h
      end
      alias_method :eql?, :==

      # @return [Integer]
      def hash
        to_h.hash
      end

      private

      def compact_metadata(metadata)
        (metadata || {}).each_with_object({}) do |(key, value), acc|
          next if value.nil?
          next if value.respond_to?(:empty?) && value.empty?
          acc[key.to_s] = value
        end
      end
    end
  end
end
