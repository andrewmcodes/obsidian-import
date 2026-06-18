# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://rubygems.org RubyGems} registry.
      #
      # Supports the +gem+ object type. Requires no credentials.
      class RubyGems < Base
        object_types "gem"
        source_name "RubyGems"

        # @return [String]
        BASE_URL = "https://rubygems.org/api/v1"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          records = client.get("/search.json", params: {query: query})
          Array(records).map { |record| normalize(record: record) }
        end

        # @param id [String] the gem name
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("/gems/#{id}.json"))
        end

        # @param record [Hash] a RubyGems API gem object
        # @return [Resource]
        def normalize(record:)
          name = record["name"]
          build(
            title: name,
            subtype: "gem",
            source_id: name,
            description: record["info"],
            source_url: record["project_uri"] || "https://rubygems.org/gems/#{name}",
            metadata: {
              "version" => record["version"],
              "downloads" => record["downloads"],
              "authors" => authors(record["authors"]),
              "homepage_url" => record["homepage_uri"],
              "github_url" => record["source_code_uri"],
              "documentation_url" => record["documentation_uri"],
              "licenses" => Array(record["licenses"])
            },
            tags: ["gem"]
          )
        end

        private

        def authors(value)
          return [] if value.nil?
          value.split(",").map(&:strip).reject(&:empty?)
        end

        def base_url
          BASE_URL
        end
      end
    end
  end
end
