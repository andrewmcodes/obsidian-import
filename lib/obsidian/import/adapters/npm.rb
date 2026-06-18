# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://www.npmjs.com npm} registry.
      #
      # Supports the +npm_package+ object type. Requires no credentials.
      class Npm < Base
        object_types "npm_package"
        source_name "npm"

        # @return [String]
        BASE_URL = "https://registry.npmjs.org"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/-/v1/search", params: {text: query, size: 10})
          Array(response["objects"]).map { |object| normalize(record: object["package"]) }
        end

        # @param id [String] the package name
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get(id))
        end

        # Normalize a raw npm record into a {Resource}.
        #
        # Tolerates both the abbreviated +package+ shape returned by the search
        # endpoint and the full registry document returned by a package lookup.
        #
        # @param record [Hash] an npm search +package+ object or registry document
        # @return [Resource]
        def normalize(record:)
          name = record["name"]
          version = record.dig("dist-tags", "latest") || record["version"]
          build(
            title: name,
            subtype: "npm",
            source_id: name,
            description: record["description"],
            source_url: "https://www.npmjs.com/package/#{name}",
            metadata: {
              "version" => version,
              "homepage_url" => record["homepage"] || record.dig("links", "homepage"),
              "github_url" => github_url(record),
              "license" => record["license"],
              "keywords" => Array(record["keywords"]),
              "author" => author(record["author"])
            },
            tags: ["npm"]
          )
        end

        private

        def github_url(record)
          url = record.dig("repository", "url") || record.dig("links", "repository")
          return if url.nil?
          url.sub(/\Agit\+/, "").sub(/\.git\z/, "")
        end

        def author(value)
          value.is_a?(Hash) ? value["name"] : value
        end

        def base_url
          BASE_URL
        end
      end
    end
  end
end
