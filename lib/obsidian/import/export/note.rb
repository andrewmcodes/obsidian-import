# frozen_string_literal: true

module Obsidian
  module Import
    module Export
      # An Obsidian note rendered from a {Resource}: standardized frontmatter
      # followed by a templated Markdown body.
      class Note
        # @return [Resource]
        attr_reader :resource

        # @param resource [Resource]
        def initialize(resource)
          @resource = resource
        end

        # @return [String] the YAML frontmatter block.
        def frontmatter
          Frontmatter.render(resource)
        end

        # @return [String] the Markdown body (no frontmatter).
        def body
          Template.body_for(resource)
        end

        # @return [String] the complete note: frontmatter + body.
        def to_markdown
          "#{frontmatter}\n#{body}"
        end
        alias_method :to_s, :to_markdown

        # @return [String] the base slug derived from the title.
        def slug
          Filename.slugify(resource.title)
        end

        # The secondary filename extension for software notes (e.g. "gem"),
        # or nil for other object types.
        #
        # @return [String, nil]
        def secondary_extension
          return nil unless Template::SOFTWARE_TYPES.include?(resource.type)
          (resource.subtype.nil? || resource.subtype.empty?) ? nil : resource.subtype
        end
      end
    end
  end
end
