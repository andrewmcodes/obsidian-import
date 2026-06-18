# frozen_string_literal: true

require "yaml"

module Obsidian
  module Import
    module Export
      # Renders a {Resource} into standardized YAML frontmatter.
      #
      # Core fields appear first, in canonical order, followed by flattened
      # adapter-specific metadata, with +tags+ last. Nested objects are avoided
      # and long values are not hard-wrapped, keeping the output human-readable.
      module Frontmatter
        # Core fields rendered first, in this order.
        CORE_ORDER = %w[type subtype title description source source_id source_url].freeze

        module_function

        # @param resource [Resource]
        # @return [String] the frontmatter block, including +---+ delimiters.
        def render(resource)
          yaml = to_hash(resource).to_yaml(line_width: -1)
          body = yaml.sub(/\A---\n/, "")
          body += "\n" unless body.end_with?("\n")
          "---\n#{body}---\n"
        end

        # @param resource [Resource]
        # @return [Hash{String=>Object}] ordered frontmatter hash.
        def to_hash(resource)
          data = {}
          core = resource.core_fields
          CORE_ORDER.each { |field| data[field] = scalarize(core[field.to_sym]) }

          resource.metadata.each do |key, value|
            next if CORE_ORDER.include?(key.to_s) || key.to_s == "tags"
            data[key.to_s] = scalarize(value)
          end

          data["tags"] = resource.tags
          data
        end

        # Coerce values into frontmatter-safe scalars/arrays. Nested hashes are
        # collapsed to their inspected form rather than emitted as nested YAML.
        #
        # @api private
        def scalarize(value)
          case value
          when Array
            value.map { |v| v.is_a?(Hash) ? v.to_s : v }
          when Hash
            value.to_s
          else
            value
          end
        end
      end
    end
  end
end
